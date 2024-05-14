// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";
import "./Interfaces/ICollTokenPriceFeed.sol"

contract SysConfig is Ownable {
    struct ConfigData {
        uint mcr;
        uint ccr;
        uint gasCompensation;
        uint minNetDebt;
        address troveManager;
        address sortedTroves;
    }

    mapping (address => ConfigData) public tokenConfigData;
    ICollTokenPriceFeed private collTokenPriceFeed;

    function updateConfig(address _collToken, ConfigData memory _tokenConfigData) external onlyOwner {
       tokenConfigData[_collToken] = _tokenConfigData;
    }

    function configData(address _collToken) view external returns (ConfigData memory) {
        return tokenConfigData[_collToken];
    }

    function updateCollTokenPriceFeed(address _collTokenPriceFeed) external onlyOwner {
        collTokenPriceFeed = ICollTokenPriceFeed(_collTokenPriceFeed);
    }

    function getCollTokenPriceFeed() view external returns (addess) {
        return collTokenPriceFeed;
    }

}