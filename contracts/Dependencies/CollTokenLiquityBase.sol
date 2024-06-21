// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./BaseMath.sol";
import "./LiquityMath.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/ICollTokenDefaultPool.sol";
import "../Interfaces/ICollTokenPriceFeed.sol";
import "../Interfaces/ICollTokenLiquityBase.sol";

/* 
* Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
* common functions. 
*/
contract CollTokenLiquityBase is BaseMath {
    using SafeMath for uint;

    uint constant public _100pct = 1000000000000000000; // 1e18 == 100%

    // // // Minimum collateral ratio for individual troves
    uint public MCR; // 130%

    // // Critical system collateral ratio. If the system's total collateral ratio (TCR) falls below the CCR, Recovery Mode is triggered.
    uint public CCR; // 150%

    // Amount of LUSD to be locked in gas pool on opening troves
    uint constant public LUSD_GAS_COMPENSATION = 1e18;

    // Minimum amount of net LUSD debt a trove must have
    uint constant public MIN_NET_DEBT = 100e18;

    uint constant public PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    uint constant public BORROWING_FEE_FLOOR = DECIMAL_PRECISION / 1000 * 5; // 0.5%

    IActivePool public activePool;

    ICollTokenDefaultPool public defaultPool;

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(uint _debt) internal pure returns (uint) {
        return _debt.add(LUSD_GAS_COMPENSATION);
    }

    function _getNetDebt(uint _debt) internal pure returns (uint) {
        return _debt.sub(LUSD_GAS_COMPENSATION);
    }

    function _requireUserAcceptsFee(uint _fee, uint _amount, uint _maxFeePercentage) internal pure {
        uint feePercentage = _fee.mul(DECIMAL_PRECISION).div(_amount);
        require(feePercentage <= _maxFeePercentage, "!Fee");
    }
}
