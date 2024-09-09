// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;

import "./Dependencies/SafeERC20.sol";
import "./Dependencies/OwnableUpgradeable.sol";
import "./Dependencies/Initializable.sol";
import "./Dependencies/AggregatorV3Interface.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/IERC20.sol";
import "./Dependencies/SysConfig.sol";
import "./Interfaces/ILUSDToken.sol";


/**
 * @title Peg Stability for WEN PSM module.
 * @notice Contract for swapping stable token(widely accepted stable tokens alike USDC) for WEN token and vice versa to maintain the peg stability between them.
 * @author Magma
 */
contract PegStability is OwnableUpgradeable, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Helper enum for fee calculation
    enum FeeDirection {
        IN,
        OUT
    }

    /// @notice The divisor used to convert fees to basis points.
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    /// @notice The mantissa value representing 1 (used for calculations).
    uint256 public constant MANTISSA_ONE = 1e8;

    /// @notice The value representing one dollar in the stable token.
    uint256 public immutable ONE_DOLLAR;

    /// @notice WEN token contract.
    ILUSDToken public immutable WEN;

    /// @notice The address of the stable token contract.
    address public immutable STABLE_TOKEN_ADDRESS;

    SysConfig public immutable sysConfig;

    AggregatorV3Interface public stableTokenPriceOracle;

    address public magmaTreasury;

    /// @notice The incoming stableCoin fee. (Fee for swapStableForWEN).
    uint256 public feeIn;

    /// @notice The outgoing stableCoin fee. (Fee for swapWENForStable).
    uint256 public feeOut;

    /// @notice The maximum amount of WEN that can be minted through this contract.
    uint256 public wenMintCap;

    /// @notice The total amount of WEN minted through this contract.
    uint256 public wenMinted;

    /// @notice A flag indicating whether the contract is currently paused or not.
    bool public isPaused;

    /// @notice Event emitted when contract is paused.
    event PSMPaused(address indexed admin);

    /// @notice Event emitted when the contract is resumed after pause.
    event PSMResumed(address indexed admin);

    /// @notice Event emitted when feeIn state var is modified.
    event FeeInChanged(uint256 oldFeeIn, uint256 newFeeIn);

    /// @notice Event emitted when feeOut state var is modified.
    event FeeOutChanged(uint256 oldFeeOut, uint256 newFeeOut);

    /// @notice Event emitted when wenMintCap state var is modified.
    event WENMintCapChanged(uint256 oldCap, uint256 newCap);

    /// @notice Event emitted when magmaTreasury state var is modified.
    event MagmaTreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Event emitted when oracle state var is modified.
    event OracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when stable token is swapped for WEN.
    event StableForWENSwapped(uint256 stableIn, uint256 wenOut, uint256 fee);

    /// @notice Event emitted when stable token is swapped for WEN.
    event WENForStableSwapped(uint256 wenBurnt, uint256 stableOut, uint256 fee);

    /**
     * @dev Prevents functions to execute when contract is paused.
     */
    modifier isActive() {
        require(!isPaused, "Paused!");
        _;
    }

    constructor(address stableToken, address wen, address _sysConfig) public {
        _ensureNonzeroAddress(stableToken);
        _ensureNonzeroAddress(wen);
        _ensureNonzeroAddress(_sysConfig);

        ONE_DOLLAR = 1e8;
        STABLE_TOKEN_ADDRESS = stableToken;
        WEN = ILUSDToken(wen);
        sysConfig = SysConfig(_sysConfig);
        _disableInitializers();
    }

    function initialize(
        address _magmaTreasury,
        address oracleAddress,
        uint256 _feeIn,
        uint256 _feeOut,
        uint256 _wenMintCap_
    ) initializer external {
        _ensureNonzeroAddress(_magmaTreasury);
        _ensureNonzeroAddress(oracleAddress);

        require(feeIn < BASIS_POINTS_DIVISOR && feeOut < BASIS_POINTS_DIVISOR, "Invalid fee");

        magmaTreasury = _magmaTreasury;
        stableTokenPriceOracle = AggregatorV3Interface(oracleAddress);
        feeIn = _feeIn;
        feeOut = _feeOut;
        wenMintCap = _wenMintCap_;
        __Ownable_init();
    }

    /*** Swap Functions ***/

    /**
     * @notice Swaps WEN for a stable token.
     * @param receiver The address where the stablecoin will be sent.
     * @param stableTknAmount The amount of stable tokens to receive.
     * @return The amount of WEN received and burnt from the sender.
     */
    // @custom:event Emits WENForStableSwapped event.
    function swapWENForStable(
        address receiver,
        uint256 stableTknAmount
    ) external isActive returns (uint256) {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);

        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount, FeeDirection.OUT);
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.OUT);

        require(WEN.balanceOf(msg.sender) >= stableTknAmountUSD + fee, "No enough WEN");
        require(wenMinted >= stableTknAmountUSD, "Win minted underflow");

        
        wenMinted = wenMinted.sub(stableTknAmountUSD);
        

        if (fee != 0) {
            WEN.transferFrom(msg.sender, magmaTreasury, fee);
        }

        sysConfig.burnLUSD(msg.sender, stableTknAmountUSD);
        IERC20(STABLE_TOKEN_ADDRESS).safeTransfer(receiver, stableTknAmount);
        emit WENForStableSwapped(stableTknAmountUSD, stableTknAmount, fee);
        return stableTknAmountUSD;
    }

    /**
     * @notice Swaps stable tokens for WEN with fees.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the WEN tokens.
     * @param stableTknAmount The amount of stable tokens to be swapped.
     * @return Amount of WEN minted to the sender.
     */
    // @custom:event Emits StableForWENSwapped event.
    function swapStableForWEN(
        address receiver,
        uint256 stableTknAmount
    ) external isActive returns (uint256) {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20(STABLE_TOKEN_ADDRESS).balanceOf(address(this));
        IERC20(STABLE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), stableTknAmount);
        uint256 balanceAfter = IERC20(STABLE_TOKEN_ADDRESS).balanceOf(address(this));

        //calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;

        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(actualTransferAmt, FeeDirection.IN);

        //calculate feeIn
        uint256 fee = _calculateFee(actualTransferAmtInUSD, FeeDirection.IN);
        uint256 wenToMint = actualTransferAmtInUSD - fee;

        require(wenMinted + actualTransferAmtInUSD <= wenMintCap, "Wen mint cap reached");
      
        wenMinted += actualTransferAmtInUSD;

        // mint WEN to receiver
        sysConfig.mintLUSD(receiver, wenToMint);

        // mint WEN fee to magma treasury
        if (fee != 0) {
            sysConfig.mintLUSD(magmaTreasury, fee);
        }

        emit StableForWENSwapped(actualTransferAmt, wenToMint, fee);
        return wenToMint;
    }

    /*** Admin Functions ***/

    /**
     * @notice Pause the PSM contract.
     * @dev Reverts if the contract is already paused.
     */
    // @custom:event Emits PSMPaused event.
    function pause() external onlyOwner {
        require(!isPaused, "Already paused");
   
        isPaused = true;
        emit PSMPaused(msg.sender);
    }

    /**
     * @notice Resume the PSM contract.
     * @dev Reverts if the contract is not paused.
     */
    // @custom:event Emits PSMResumed event.
    function resume() external onlyOwner {
        require(isPaused, "Not paused");
     
        isPaused = false;
        emit PSMResumed(msg.sender);
    }

    /**
     * @notice Set the fee percentage for incoming swaps.
     * @dev Reverts if the new fee percentage is invalid (greater than or equal to BASIS_POINTS_DIVISOR).
     * @param feeIn_ The new fee percentage for incoming swaps.
     */
    // @custom:event Emits FeeInChanged event.
    function setFeeIn(uint256 feeIn_) external onlyOwner {
        // feeIn = 10000 = 100%
        require(feeIn < BASIS_POINTS_DIVISOR, "Invalid fee");
      
        uint256 oldFeeIn = feeIn;
        feeIn = feeIn_;
        emit FeeInChanged(oldFeeIn, feeIn_);
    }

    /**
     * @notice Set the fee percentage for outgoing swaps.
     * @dev Reverts if the new fee percentage is invalid (greater than or equal to BASIS_POINTS_DIVISOR).
     * @param feeOut_ The new fee percentage for outgoing swaps.
     */
    // @custom:event Emits FeeOutChanged event.
    function setFeeOut(uint256 feeOut_) external onlyOwner {
        // feeOut = 10000 = 100%
        require(feeOut < BASIS_POINTS_DIVISOR, "Invalid fee");
      
        uint256 oldFeeOut = feeOut;
        feeOut = feeOut_;
        emit FeeOutChanged(oldFeeOut, feeOut_);
    }

    /**
     * @dev Set the maximum amount of WEN that can be minted through this contract.
     * @param wenMintCap_ The new maximum amount of WEN that can be minted.
     */
    // @custom:event Emits WENMintCapChanged event.
    function setWenMintCap(uint256 wenMintCap_) external onlyOwner {
        uint256 oldWENMintCap = wenMintCap;
        wenMintCap = wenMintCap_;
        emit WENMintCapChanged(oldWENMintCap, wenMintCap_);
    }

    /**
     * @notice Set the address of the Magma Treasury address.
     * @dev Reverts if the new address is zero.
     * @param magmaTreasury_ The new address of the Magam Treasury.
     */
    // @custom:event Emits MagmaTreasuryChanged event.
    function setMagmaTreasury(address magmaTreasury_) external onlyOwner {
        _ensureNonzeroAddress(magmaTreasury_);
        address oldTreasuryAddress = magmaTreasury;
        magmaTreasury = magmaTreasury_;
        emit MagmaTreasuryChanged(oldTreasuryAddress, magmaTreasury_);
    }

    /**
     * @notice Set the address of the oracle contract.
     * @dev Reverts if the new address is zero.
     * @param oracleAddress_ The new address of the oracle contract.
     */
    // @custom:event Emits OracleChanged event.
    function setOracle(address oracleAddress_) external onlyOwner {
        _ensureNonzeroAddress(oracleAddress_);
        address oldOracleAddress = address(stableTokenPriceOracle);
        stableTokenPriceOracle = AggregatorV3Interface(oracleAddress_);
        emit OracleChanged(oldOracleAddress, oracleAddress_);
    }

    /**
     * @notice Calculates the amount of WEN that would be sent to the receiver.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param stableTknAmount The amount of stable tokens provided for the swap.
     * @return The amount of WEN that would be sent to the receiver.
     */
    function previewSwapStableForWEN(uint256 stableTknAmount) external view returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount, FeeDirection.IN);

        //calculate feeIn
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.IN);
        uint256 wenToMint = stableTknAmountUSD - fee;

        require(wenMinted + stableTknAmountUSD <= wenMintCap, "Wen mint cap reached");

        return wenToMint;
    }

    /**
     * @notice Calculates the amount of WEN that would be burnt from the user.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param stableTknAmount The amount of stable tokens to be received after the swap.
     * @return The amount of WEN that would be taken from the user.
     */
    function previewSwapWENForStable(uint256 stableTknAmount) external view returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount, FeeDirection.OUT);
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.OUT);

        require(wenMinted >= stableTknAmountUSD, "Wen minted underflow");

        return stableTknAmountUSD + fee;
    }

    /**
     * @dev Calculates the USD value of the given amount of stable tokens depending on the swap direction.
     * @param amount The amount of stable tokens.
     * @param direction The direction of the swap.
     * @return The USD value of the given amount of stable tokens scaled by 1e18 taking into account the direction of the swap
     */
    function _previewTokenUSDAmount(uint256 amount, FeeDirection direction) internal view returns (uint256) {
        return (amount * _getPriceInUSD(direction)) / MANTISSA_ONE;
    }
    /**
     * @notice Get the price of stable token in USD.
     * @dev This function returns either min(1$,oraclePrice) or max(1$,oraclePrice).
     * @param direction The direction of the swap: FeeDirection.IN or FeeDirection.OUT.
     * @return The price in USD, adjusted based on the selected direction.
     */
    function _getPriceInUSD(FeeDirection direction) internal view returns (uint256) {
        (, int currentPrice,,,) = stableTokenPriceOracle.latestRoundData();

        uint256 price = uint256(currentPrice);

        if (direction == FeeDirection.IN) {
            // MIN(1, price)
            return price < ONE_DOLLAR ? price : ONE_DOLLAR;
        } else {
            // MAX(1, price)
            return price > ONE_DOLLAR ? price : ONE_DOLLAR;
        }
    }

    /**
     * @notice Calculate the fee amount based on the input amount and fee percentage.
     * @dev Reverts if the fee percentage calculation results in rounding down to 0.
     * @param amount The input amount to calculate the fee from.
     * @param direction The direction of the fee: FeeDirection.IN or FeeDirection.OUT.
     * @return The fee amount.
     */
    function _calculateFee(uint256 amount, FeeDirection direction) internal view returns (uint256) {
        uint256 feePercent;
        if (direction == FeeDirection.IN) {
            feePercent = feeIn;
        } else {
            feePercent = feeOut;
        }
        if (feePercent == 0) {
            return 0;
        } else {
            // checking if the percent calculation will result in rounding down to 0
            require(amount * feePercent >= BASIS_POINTS_DIVISOR, "Amount too small.");
            return (amount * feePercent) / BASIS_POINTS_DIVISOR;
        }
    }

    /**
     * @notice Checks that the address is not the zero address.
     * @param addr The address to check.
     */
    function _ensureNonzeroAddress(address addr) private pure {
        require(addr != address(0x0), "Zero addr!");
    }

    /**
     * @notice Checks that the amount passed as stable tokens is bigger than zero
     * @param amount The amount to validate
     */
    function _ensureNonzeroAmount(uint256 amount) private pure {
        require(amount != 0, "Zero amount!");
    }
}