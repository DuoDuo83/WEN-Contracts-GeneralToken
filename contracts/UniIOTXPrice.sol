// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Dependencies/AggregatorV3Interface.sol";
import "./Dependencies/IIOTXStaking.sol";

contract UniIOTXPrice is AggregatorV3Interface {
    IIOTXStaking public iotxStaking;
    AggregatorV3Interface public iotxPriceOracle;

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
        uint256 exchangeRatio = iotxStaking.exchangeRatio();
        (uint80 iotxRoundId, int currentIOTXPrice, uint256 iotxStartedAt, uint256 iotxUpdatedAt, uint80 iotxAnsweredInRound) = iotxPriceOracle.latestRoundData();

        require(iotxAnsweredInRound >= iotxRoundId, "Stale price");
        require(iotxUpdatedAt != 0, "Round not complete");
        require(block.timestamp - iotxUpdatedAt <= 24 hours, "Price too old");

        answer = _toInt256(exchangeRatio) * currentIOTXPrice / 1e18;
        startedAt = iotxStartedAt;
        updatedAt = iotxUpdatedAt;
        answeredInRound = iotxAnsweredInRound;

        require(answer > 0, "Price <= 0");
        require((answer + currentIOTXPrice)/currentIOTXPrice == 2, " Invalid price");
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

    function _toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "Value doesn't fit in an int256");
        return int256(value);
    }
}
