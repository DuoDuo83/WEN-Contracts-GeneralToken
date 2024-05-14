// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./IPool.sol";


interface IActivePool is IPool {
    // --- Events ---
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolLUSDDebtUpdated(uint _LUSDDebt);
    event ActivePoolETHBalanceUpdated(uint _ETH);

    event ActivePoolTokenStableDebtUpdated(address _collToken, uint _LUSDDebt);
    event ActivePoolCollTokenBalanceUpdated(address _collToken, uint _amount);


    // --- Functions ---
    function sendETH(address _account, uint _amount) external;
    function sendCollToken(address _collToken, address _account, uint _amount) external;
}
