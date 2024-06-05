// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./IPool.sol";


interface ICollTokenDefaultPool {
    // --- Events ---
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);

    event EtherSent(address _to, uint _amount);
    event CollTokenSent(address _collToken, address _to, uint _amount);
    event CollTokenBalanceUpdated(address _collToken, uint _newBalance);
    event StableBalanceUpdated(uint _newBalance);

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolLUSDDebtUpdated(uint _LUSDDebt);
    event DefaultPoolETHBalanceUpdated(uint _ETH);

    // --- Functions ---
    function getETH() external view returns (uint);
    function getLUSDDebt() external view returns (uint);

    // function getTokenCollateral(address _collToken) external view;
    // function getTokenStableDebt(address _collToken) external view;
    // function receiveCollToken(address _collToken, uint _amount) external;
    function sendCollTokenToActivePool(address _collToken, uint _amount) external;
    // function getTokenCollateral(address _collToken) external view returns (uint);
    // function getTokenStableDebt(address _collToken) external view returns (uint);
    // function increaseTokenStableDebt(address _collToken, uint _amount) external;
    // function decreaseTokenStableDebt(address collToken, uint _amount) external;

    function increaseLUSDDebt(uint _amount) external;
    function decreaseLUSDDebt(uint _amount) external;
}
