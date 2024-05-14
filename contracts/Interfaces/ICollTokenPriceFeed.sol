// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICollTokenPriceFeed {

    // --- Events ---
    event LastGoodPriceUpdated(address _collToken, uint _lastGoodPrice);
   
    // --- Function ---
    function fetchPrice(address _collToken) external returns (uint);
}
