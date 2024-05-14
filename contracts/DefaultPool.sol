// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import './Interfaces/IDefaultPool.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/IERC20.sol";

/*
 * The Default Pool holds the ETH and LUSD debt (but not LUSD tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending ETH and LUSD debt, its pending ETH and LUSD debt is moved
 * from the Default Pool to the Active Pool.
 */
contract DefaultPool is Ownable, CheckContract, IDefaultPool {
    using SafeMath for uint256;

    string constant public NAME = "DefaultPool";

    address public troveManagerAddress;
    address public activePoolAddress;

    mapping(address => uint256) internal tokenCollateral;
    mapping(address => uint256) internal tokenStableDebt;

    event TroveManagerAddressChanged(address _newTroveManagerAddress);

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
    // --- Getters for public variables. Required by IPool interface ---
    function getTokenCollateral(address _collToken) external view returns (uint) {
        return tokenCollateral[_collToken];
    }

    function getTokenStableDebt(address _collToken) external view override returns (uint) {
        return tokenDebt[_collToken];
    }

    // --- Pool functionality ---

    function sendCollTokenToActivePool(address _collToken, uint _amount) external override {
        _requireCallerIsTroveManager();
        address activePool = activePoolAddress; // cache to save an SLOAD
        tokenCollateral[_collToken] = tokenCollateral[_collToken].sub(_amount);
        emit DefaultPoolCollTokenBalanceUpdated(tokenCollateral[_collToken]);
        emit CollTokenSent(_collToken, activePool, _amount);

        if (isNativeToken(_collToken)) {
            (bool success, ) = activePool.call{ value: _amount }("");
            require(success, "DefaultPool: sending Native Token failed");
            return;
        }
        IERC20(_collToken).transfer(_account, _amount);
    }

    function increaseTokenStableDebt(address _collToken, uint _amount) external override {
        _requireCallerIsBOorTroveM();
        tokenStableDebt[_collToken]  = tokenStableDebt[_collToken].add(_amount);
        emit ActivePoolTokenStableDebtUpdated(_collToken, tokenStableDebt[_collToken]);
    } 

    function decreaseTokenStableDebt(address _collToken, uint _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        tokenStableDebt[_collToken] = tokenStableDebt[_collToken].sub(_amount);
        emit ActivePoolTokenStableDebtUpdated(LUSDDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "DefaultPool: Caller is not the TroveManager");
    }

    // --- Fallback function ---

    receive() external payable {
        _requireCallerIsActivePool();
        tokenCollateral[address(0x0)] = tokenCollateral[address(0x0)].add(msg.value);
        emit DefaultPoolCollTokenBalanceUpdated(address(0x0));
    }
}
