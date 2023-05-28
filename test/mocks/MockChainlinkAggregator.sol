// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import "../../src/interfaces/IAggregatorV3.sol";

contract MockChainlinkAggregator is IAggregatorV3 {
    uint8 private immutable d;

    // chainlink stored answer and timestamp in single slot
    // we do the same to stimulate gas cost
    struct MockState {
        uint80 roundId;
        int192 answer;
        uint64 timestamp;
    }

    struct RoundData {
        int192 answer;
        uint64 timestamp;
    }

    MockState public state;

    mapping(uint80 => RoundData) public rounds;

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

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory round = rounds[_roundId];
        return (_roundId, round.answer, round.timestamp, round.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (state.roundId, state.answer, state.timestamp, state.timestamp, state.roundId);
    }

    function setMockState(uint80 roundId, int256 answer, uint256 timestamp) external {
        // set unused filed to 1 to have more accurate approximation of gas cost of reading.
        state = MockState(roundId, int192(answer), uint64(timestamp));
    }

    function setMockRound(uint80 roundId, int256 answer, uint256 timestamp) external {
        // set unused filed to 1 to have more accurate approximation of gas cost of reading.
        rounds[roundId] = RoundData(int192(answer), uint64(timestamp));
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
