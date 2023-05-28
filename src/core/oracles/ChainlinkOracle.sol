// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

// interfaces
import {IOracle} from "../../interfaces/IOracle.sol";
import {IAggregatorV3} from "../../interfaces/IAggregatorV3.sol";

// constants and types
import "./errors.sol";
import "../../config/constants.sol";

/**
 * @title ChainlinkOracle
 * @author @antoncoding
 * @dev return base / quote price, with 6 decimals
 */
contract ChainlinkOracle is IOracle, Ownable {
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    struct ExpiryPrice {
        bool isDisputed;
        uint64 reportAt;
        uint128 price;
    }

    struct AggregatorData {
        address addr;
        uint8 decimals;
        uint32 maxDelay;
        bool isStable; // answer of stable asset can be used as long as the answer is not stale
    }

    ///@dev base => quote => expiry => price.
    mapping(address => mapping(address => mapping(uint256 => ExpiryPrice))) public expiryPrices;

    // asset => aggregator
    mapping(address => AggregatorData) public aggregators;

    /*///////////////////////////////////////////////////////////////
                                 Events
    //////////////////////////////////////////////////////////////*/

    event ExpiryPriceSet(address base, address quote, uint256 expiry, uint256 price, bool isDispute);

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  get spot price of _base, denominated in _quote.
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @return price with 6 decimals
     */
    function getSpotPrice(address _base, address _quote) external view returns (uint256) {
        (uint256 basePrice, uint8 baseDecimals) = _getSpotPriceFromAggregator(_base);
        (uint256 quotePrice, uint8 quoteDecimals) = _getSpotPriceFromAggregator(_quote);
        return _toPriceWithUnitDecimals(basePrice, quotePrice, baseDecimals, quoteDecimals);
    }

    /**
     * @dev get expiry price of underlying, denominated in strike asset.
     *         can revert if expiry is in the future, or the price has not been reported by authorized party
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @param _expiry expiry timestamp
     * @return price with 6 decimals
     */
    function getPriceAtExpiry(address _base, address _quote, uint256 _expiry)
        external
        view
        returns (uint256 price, bool isFinalized)
    {
        ExpiryPrice memory data = expiryPrices[_base][_quote][_expiry];
        if (data.reportAt == 0) revert OC_PriceNotReported();

        return (data.price, _isExpiryPriceFinalized(_base, _quote, _expiry));
    }

    /**
     * @dev return the maximum dispute period for the oracle
     * @dev this oracle has no dispute mechanism, as long as a price is reported, it can be used to settle.
     */
    function maxDisputePeriod() external view virtual returns (uint256) {
        return 0;
    }

    /**
     * @notice report expiry price and write to storage
     * @dev anyone can call this function and freeze the expiry price
     */
    function reportExpiryPrice(address _base, address _quote, uint256 _expiry, uint80 _baseRoundId, uint80 _quoteRoundId)
        external
    {
        if (_expiry > block.timestamp) revert OC_CannotReportForFuture();
        if (expiryPrices[_base][_quote][_expiry].reportAt != 0) revert OC_PriceReported();

        (uint256 basePrice, uint8 baseDecimals) = _getLastPriceBeforeExpiry(_base, _baseRoundId, _expiry);
        (uint256 quotePrice, uint8 quoteDecimals) = _getLastPriceBeforeExpiry(_quote, _quoteRoundId, _expiry);
        uint256 price = _toPriceWithUnitDecimals(basePrice, quotePrice, baseDecimals, quoteDecimals);

        expiryPrices[_base][_quote][_expiry] = ExpiryPrice(false, uint64(block.timestamp), price.safeCastTo128());

        emit ExpiryPriceSet(_base, _quote, _expiry, price, false);
    }

    /*///////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev admin function to set aggregator address for an asset
     */
    function setAggregator(address _asset, address _aggregator, uint32 _maxDelay, bool _isStable) external onlyOwner {
        uint8 decimals = IAggregatorV3(_aggregator).decimals();
        aggregators[_asset] = AggregatorData(_aggregator, decimals, _maxDelay, _isStable);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev this oracle has no dispute mechanism, so always return true.
     *      a un-reported price should have reverted at this point.
     */
    function _isExpiryPriceFinalized(address, address, uint256) internal view virtual returns (bool) {
        return true;
    }

    /**
     * @notice  convert prices from aggregator of base & quote asset to base / quote, denominated in UNIT
     * @param _basePrice price of base asset from aggregator
     * @param _quotePrice price of quote asset from aggregator
     * @param _baseDecimals decimals of _basePrice
     * @param _quoteDecimals decimals of _quotePrice
     * @return price base / quote price with {UNIT_DECIMALS} decimals
     */
    function _toPriceWithUnitDecimals(uint256 _basePrice, uint256 _quotePrice, uint8 _baseDecimals, uint8 _quoteDecimals)
        internal
        pure
        returns (uint256 price)
    {
        if (_baseDecimals == _quoteDecimals) {
            // .mul UNIT to make sure the final price has 6 decimals
            price = _basePrice.mulDivUp(UNIT, _quotePrice);
        } else {
            // we will return basePrice * 10^(baseMulDecimals) / quotePrice;
            int8 baseMulDecimals = int8(UNIT_DECIMALS) + int8(_quoteDecimals) - int8(_baseDecimals);
            if (baseMulDecimals > 0) {
                price = _basePrice.mulDivUp(10 ** uint8(baseMulDecimals), _quotePrice);
            } else {
                price = _basePrice / (_quotePrice * (10 ** uint8(-baseMulDecimals)));
            }
        }
    }

    /**
     * @dev fetch price with their native decimals from Chainlink aggregator
     */
    function _getSpotPriceFromAggregator(address _asset) internal view returns (uint256 price, uint8 decimals) {
        AggregatorData memory aggregator = aggregators[_asset];
        if (aggregator.addr == address(0)) revert CL_AggregatorNotSet();

        // request answer from Chainlink
        (, int256 answer,, uint256 updatedAt,) = IAggregatorV3(address(aggregator.addr)).latestRoundData();

        if (block.timestamp - updatedAt > aggregator.maxDelay) revert CL_StaleAnswer();

        return (uint256(answer), aggregator.decimals);
    }

    /**
     * @notice get the price from an roundId, and make sure it is the last price before expiry
     * @param _asset asset to report
     * @param _roundId chainlink roundId that should be used
     * @param _expiry expiry timestamp to report
     */
    function _getLastPriceBeforeExpiry(address _asset, uint80 _roundId, uint256 _expiry)
        internal
        view
        returns (uint256 price, uint8 decimals)
    {
        AggregatorData memory aggregator = aggregators[_asset];
        if (aggregator.addr == address(0)) revert CL_AggregatorNotSet();

        // request answer from Chainlink
        (, int256 answer,, uint256 updatedAt,) = IAggregatorV3(address(aggregator.addr)).getRoundData(_roundId);

        // if expiry < updatedAt, this line will revert
        if (_expiry - updatedAt > aggregator.maxDelay) revert CL_StaleAnswer();

        // it is not a stable asset: make sure timestamp of answer #(round + 1) is higher than expiry
        if (!aggregator.isStable) {
            (,,, uint256 nextRoundUpdatedAt,) = IAggregatorV3(address(aggregator.addr)).getRoundData(_roundId + 1);
            if (nextRoundUpdatedAt <= _expiry) revert CL_RoundIdTooSmall();
        }

        return (uint256(answer), aggregator.decimals);
    }
}
