// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.13;

import "src/interfaces/IAggregatorV3.sol";

contract MockChainlinkAggregator is IAggregatorV3 {
    uint8 private immutable d;

    struct StoredData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    StoredData public state;

    constructor(uint8 _decimals) {
        d = _decimals;
    }

    function decimals() external view returns (uint8) {
        return d;
    }

    function description() external pure returns (string memory) {
        return "mocked aggreagtor!";
    }

    function version() external pure returns (uint256) {
        return 2;
    }

    function getRoundData(
        uint80 /*roundId*/
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (state.roundId, state.answer, state.startedAt, state.updatedAt, state.answeredInRound);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (state.roundId, state.answer, state.startedAt, state.updatedAt, state.answeredInRound);
    }

    function setMockState(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt
    ) external {
        // set unused filed to 1 to have more accurate approximation of gas cost of reading.
        state = StoredData(roundId, answer, 1, updatedAt, 1);
    }
}
