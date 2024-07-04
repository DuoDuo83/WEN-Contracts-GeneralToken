// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Interfaces/IPriceFeed.sol";
import "./Dependencies/AggregatorV3Interface.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/OwnableUpgradeable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/BaseMath.sol";
import "./Dependencies/LiquityMath.sol";
import "./Dependencies/Initializable.sol";
import "./Interfaces/ICollTokenPriceFeed.sol";

contract PriceFeedTestnet is IPriceFeed, ICollTokenPriceFeed {
    
    uint256 private _price = 200 * 1e18;

    // --- Functions ---
    function initialize() external {

    }
    // View price getter for simplicity in tests
    function getPrice() external view returns (uint256) {
        return _price;
    }

    function fetchPrice(address _collToken) external override returns (uint) {
        _collToken;
        return _price * 90 / 100;
    }

    function fetchPrice() external override returns (uint256) {
        // Fire an event just like the mainnet version would.
        // This lets the subgraph rely on events to get the latest price even when developing locally.
        emit LastGoodPriceUpdated(_price);
        return _price;
    }

    // Manual external price setter.
    function setPrice(uint256 price) external returns (bool) {
        _price = price;
        return true;
    }
}
