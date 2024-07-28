// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Dependencies/AggregatorV3Interface.sol";
import "./Dependencies/IIOTXStaking.sol";

contract UniIOTXPrice is AggregatorV3Interface {
    IIOTXStaking public iotxStaking;
    AggregatorV3Interface iotxPriceOracle;

    constructor(IIOTXStaking _iotxStaking, AggregatorV3Interface _iotxPriceOracle) public {
        iotxStaking = _iotxStaking;
        iotxPriceOracle = _iotxPriceOracle;
        require(iotxPriceOracle.decimals() == 8, "Invalid iotx price oracle");
    }

    function decimals() external view override returns (uint8) {
        return 8;
    }

    function description() external view override returns (string memory) {
        return "UniIOTX price oracle";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) public view override returns (
                                                                            uint80 roundId,
                                                                            int256 answer,
                                                                            uint256 startedAt,
                                                                            uint256 updatedAt,
                                                                            uint80 answeredInRound) {
            roundId = _roundId;
            uint exchangeRatio = iotxStaking.exchangeRatio();
            (, int currentIOTXPrice,,,) = iotxPriceOracle.latestRoundData();
            answer = int(exchangeRatio) * currentIOTXPrice / 1e18;
            startedAt = block.timestamp;
            updatedAt = block.timestamp;
            answeredInRound = roundId;

            require(answer != 0, "price is 0");
            require((answer + currentIOTXPrice)/currentIOTXPrice == 2, " invalid price");
        }

    function latestRoundData() external view override returns (
                                                                uint80 roundId,
                                                                int256 answer,
                                                                uint256 startedAt,
                                                                uint256 updatedAt,
                                                                uint80 answeredInRound
                                                            ) {
            return getRoundData(100);
        }
}
