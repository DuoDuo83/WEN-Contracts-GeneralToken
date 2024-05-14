// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

// Common interface for the Pools.
interface IPool {
    
    // --- Events ---
    
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);

    event CollTokenSent(address _collToken, address _to, uint _amount);
    event CollTokenBalanceUpdated(address _collToken, uint _newBalance);
    event StableBalanceUpdated(uint _newBalance);
    // --- Functions ---
    function getTokenCollateral(address _collToken) external view returns (uint);

    function getTokenStableDebt(address _collToken) external view returns (uint);

    function increaseTokenStableDebt(address _collToken, uint _amount) external;

    function decreaseTokenStableDebt(address _collToken, uint _amount) external;
}
