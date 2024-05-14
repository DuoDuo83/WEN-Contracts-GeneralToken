// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./IPool.sol";


interface IDefaultPool is IPool {
    // --- Events ---
    event TroveManagerAddressChanged(address _newTroveManagerAddress);

    event DefaultPoolTokenStableDebtUpdated(address _collToken, uint _tokenStableAmount);
    event DefaultPoolCollTokenBalanceUpdated(address _collToken, uint _amount);
    // --- Functions ---
    function sendCollTokenToActivePool(address _collToken, uint _amount) external;
}
