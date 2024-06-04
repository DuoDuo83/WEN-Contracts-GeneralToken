// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./ICollTokenPriceFeed.sol";


interface ICollTokenLiquityBase {
    function priceFeed() external view returns (ICollTokenPriceFeed);
}
