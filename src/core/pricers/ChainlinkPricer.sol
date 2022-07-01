// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {IOracle} from "src/interfaces/IOracle.sol";
import {IPricer} from "src/interfaces/IPricer.sol";
import {IAggregatorV3} from "src/interfaces/IAggregatorV3.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "src/config/errors.sol";

/**
 * @title ChainlinkPricer
 * @author antoncoding
 * @dev return base / quote price from requesting both prices in USD term from Chainlink Oracle
 */
contract ChainlinkPricer is IPricer, Ownable {
    using FixedPointMathLib for uint256;

    struct AggregatorData {
        uint160 addr;
        uint8 decimals;
        uint32 maxDelay;
        bool isStable; // answer of stable asset can be used as long as the answer is not stale
    }

    uint256 internal constant UNIT = 10**6;

    int8 internal constant UNIT_DECIMALS = 6;

    address public immutable oracle;

    // asset => aggregator
    mapping(address => AggregatorData) public aggregators;

    constructor(address _oracle) {
        oracle = _oracle;
    }

    /**
     * @notice return spot price for a base/quote pair
     */
    function getSpotPrice(address _base, address _quote) external view returns (uint256) {
        (uint256 basePrice, uint8 baseDecimals) = _getSpotPriceFromAggregator(_base);
        (uint256 quotePrice, uint8 quoteDecimals) = _getSpotPriceFromAggregator(_quote);
        return _toPriceWithUnitDecimals(basePrice, quotePrice, baseDecimals, quoteDecimals);
    }

    /**
     * report expiry price and write it to Oracle
     */
    function reportExpiryPrice(
        address _base,
        address _quote,
        uint256 _expiry,
        uint80 _baseRoundId,
        uint80 _quoteRoundId
    ) external {
        (uint256 basePrice, uint8 baseDecimals) = _getLastPriceBeforeExpiry(_base, _baseRoundId, _expiry);
        (uint256 quotePrice, uint8 quoteDecimals) = _getLastPriceBeforeExpiry(_quote, _quoteRoundId, _expiry);
        uint256 price = _toPriceWithUnitDecimals(basePrice, quotePrice, baseDecimals, quoteDecimals);

        IOracle(oracle).reportExpiryPrice(_base, _quote, _expiry, price);
    }

    /**
     * @dev admin function to set aggregator address for an asset
     */
    function setAggregator(
        address _asset,
        address _aggregator,
        uint32 _maxDelay,
        bool _isStable
    ) external onlyOwner {
        uint8 decimals = IAggregatorV3(_aggregator).decimals();
        aggregators[_asset] = AggregatorData(uint160(_aggregator), decimals, _maxDelay, _isStable);
    }

    /**
     * @notice  convert prices from aggregator of base & quote asset to base / quote, denominated in UNIT
     * @param _basePrice price of base asset from aggregator
     * @param _quotePrice price of quote asset from aggregator
     * @param _baseDecimals decimals of _basePrice
     * @param _quoteDecimals decimals of _quotePrice
     * @return price base / quote price with {UNIT_DECIMALS} decimals
     */
    function _toPriceWithUnitDecimals(
        uint256 _basePrice,
        uint256 _quotePrice,
        uint8 _baseDecimals,
        uint8 _quoteDecimals
    ) internal pure returns (uint256 price) {
        if (_baseDecimals == _quoteDecimals) {
            // .mul UNIT to make sure the final price has 6 decimals
            price = _basePrice.mulDivUp(UNIT, _quotePrice);
        } else {
            // we will return basePrice * 10^(baseMulDecimals) / quotePrice;
            int8 baseMulDecimals = UNIT_DECIMALS + int8(_quoteDecimals) - int8(_baseDecimals);
            if (baseMulDecimals > 0) return _basePrice.mulDivUp(10**uint8(baseMulDecimals), _quotePrice);
            price = _basePrice / (10**uint8(-baseMulDecimals)) / _quotePrice;
        }
    }

    function _getSpotPriceFromAggregator(address _asset) internal view returns (uint256 price, uint8 decimals) {
        AggregatorData memory aggregator = aggregators[_asset];
        if (aggregator.addr == 0) revert Chainlink_AggregatorNotSet();

        // request answer from Chainlink
        (, int256 answer, , uint256 updatedAt, ) = IAggregatorV3(address(aggregator.addr)).latestRoundData();

        if (block.timestamp - updatedAt > aggregator.maxDelay) revert Chainlink_StaleAnswer();

        return (uint256(answer), aggregator.decimals);
    }

    /**
     * @notice get the price from an roundId, and make sure it is the last price before expiry
     * @param _asset asset to report
     * @param _roundId chainlink roundId that should be used
     * @param _expiry expiry timestamp to report
     */
    function _getLastPriceBeforeExpiry(
        address _asset,
        uint80 _roundId,
        uint256 _expiry
    ) internal view returns (uint256 price, uint8 decimals) {
        AggregatorData memory aggregator = aggregators[_asset];
        if (aggregator.addr == 0) revert Chainlink_AggregatorNotSet();

        // request answer from Chainlink
        (, int256 answer, , uint256 updatedAt, ) = IAggregatorV3(address(aggregator.addr)).getRoundData(_roundId);

        // if expiry < updatedAt, this line will revert
        if (_expiry - updatedAt > aggregator.maxDelay) revert Chainlink_StaleAnswer();

        // it is not a stable asset: make sure timestamp of answer #(round + 1) is higher than expiry
        if (!aggregator.isStable) {
            (, , , uint256 nextRoundUpdatedAt, ) = IAggregatorV3(address(aggregator.addr)).getRoundData(_roundId + 1);
            if (nextRoundUpdatedAt < _expiry) revert Chainlink_RoundIdTooSmall();
        }

        return (uint256(answer), aggregator.decimals);
    }
}
