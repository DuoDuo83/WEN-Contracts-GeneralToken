// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import './Interfaces/ICollTokenDefaultPool.sol';
import './Interfaces/ICollTokenReceiver.sol';
import './Dependencies/IERC20.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/OwnableUpgradeable.sol";
import "./Dependencies/Initializable.sol";

/*
 * The Default Pool holds the ETH and LUSD debt (but not LUSD tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending ETH and LUSD debt, its pending ETH and LUSD debt is moved
 * from the Default Pool to the Active Pool.
 */
contract CollTokenDefaultPool is OwnableUpgradeable, CheckContract, ICollTokenDefaultPool, ICollTokenReceiver, Initializable {
    using SafeMath for uint256;

    string constant public NAME = "CollTokenDefaultPool";

    address public troveManagerAddress;
    address public activePoolAddress;
    uint256 internal ETH;  // deposited ETH tracker
    uint256 internal LUSDDebt;  // debt

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolTokenStableDebtUpdated(address _collToken, uint _LUSDDebt);
    event DefaultPoolCollTokenBalanceUpdated(address _collToken, uint _amount);


    constructor() public {
        _disableInitializers();
    }

    function initialize() initializer external {
        __Ownable_init();
    }
    // --- Dependency setters ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress
    )
        external
        onlyOwner
    {
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);

        troveManagerAddress = _troveManagerAddress;
        activePoolAddress = _activePoolAddress;

        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);

    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the ETH state variable.
    *
    * Not necessarily equal to the the contract's raw ETH balance - ether can be forcibly sent to contracts.
    */

    // --- Pool functionality ---
    // function getTokenCollateral(address _collToken) external view override returns (uint) {
    //     return tokenCollateral[_collToken];
    // }

    // function getTokenStableDebt(address _collToken) external view override returns (uint) {
    //     return tokenStableDebt[_collToken];
    // // }

    // function decreaseTokenStableDebt(address _collToken, uint _amount) external override {

    // }
    // function increaseTokenStableDebt(address _collToken, uint _amount) external override {

    // }
    // function receiveCollToken(address _collToken, uint _amount) external override {

    // }
   
    function getETH() external view override returns (uint) {
        return ETH;
    }

    function getLUSDDebt() external view override returns (uint) {
        return LUSDDebt;
    }

    function sendCollTokenToActivePool(address _collToken, uint _amount) external override {
        _requireCallerIsTroveManager();
        ETH = ETH.sub(_amount);
        emit DefaultPoolCollTokenBalanceUpdated(_collToken, ETH);
        emit CollTokenSent(_collToken, activePoolAddress, _amount);

        if (isNativeToken(_collToken)) {
            (bool success, ) = activePoolAddress.call{ value: _amount }("");
            require(success, "ActivePool: sending Native Token failed");
            return;
        }
        IERC20(_collToken).transfer(activePoolAddress, _amount);
        ICollTokenReceiver(activePoolAddress).onReceive(_collToken, _amount);
    }

    function increaseLUSDDebt(uint _amount) external override {
        _requireCallerIsTroveManager();
        LUSDDebt = LUSDDebt.add(_amount);
        emit DefaultPoolLUSDDebtUpdated(LUSDDebt);
    }

    function decreaseLUSDDebt(uint _amount) external override {
        _requireCallerIsTroveManager();
        LUSDDebt = LUSDDebt.sub(_amount);
        emit DefaultPoolLUSDDebtUpdated(LUSDDebt);
    }

    function onReceive(address _collToken, uint _amount) external override {
        _requireCallerIsActivePool();
        require(!isNativeToken(_collToken), "No native token allowed");

        ETH = ETH.add(_amount);
        emit DefaultPoolCollTokenBalanceUpdated(_collToken, _amount);
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "DefaultPool: Caller is not the TroveManager");
    }
}
