// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ChainlinkOracle} from "./ChainlinkOracle.sol";

// constants and types
import "../../config/errors.sol";

/**
 * @title ChainlinkOracleDisputable
 * @author antoncoding
 * @dev chainlink oracle that can be dispute by the owner
 */
contract ChainlinkOracleDisputable is ChainlinkOracle {
    using SafeCastLib for uint256;

    // base => quote => dispute period
    mapping(address => mapping(address => uint256)) public disputePeriod;

    event DisputePeriodUpdated(address base, address quote, uint256 period);

    /**
     * @dev return true of an expiry price should be consider finalized
     *      if a price is unreported, return false
     */
    function isExpiryPriceFinalized(
        address _base,
        address _quote,
        uint256 _expiry
    ) external view override returns (bool) {
        uint128 reportedAt = expiryPrices[_base][_quote][_expiry].reportAt;
        if (reportedAt == 0) return false;

        return block.timestamp > reportedAt + disputePeriod[_base][_quote];
    }

    /**
     * @dev dispute the expiry price from the owner. Cannot dispute an un-reported price
     * @param _base base asset
     * @param _quote quote asset
     * @param _expiry expiry timestamp
     * @param _newPrice new price to set
     */
    function disputePrice(
        address _base,
        address _quote,
        uint256 _expiry,
        uint256 _newPrice
    ) external onlyOwner {
        uint128 reportedAt = expiryPrices[_base][_quote][_expiry].reportAt;
        if (reportedAt == 0) revert OC_PriceNotReported();

        if (reportedAt + disputePeriod[_base][_quote] < block.timestamp) revert OC_DisputePeriodOver();

        expiryPrices[_base][_quote][_expiry] = ExpiryPrice(uint128(block.timestamp), _newPrice.safeCastTo128());

        emit ExpiryPriceUpdated(_base, _quote, _expiry, _newPrice, true);
    }

    /**
     * @dev set the dispute period for a specific base / quote asset
     * @param _base base asset
     * @param _quote quote asset
     * @param _period dispute period. Cannot be set to a vlue longer than 1/2 days
     */
    function setDisputePeriod(
        address _base,
        address _quote,
        uint256 _period
    ) external onlyOwner {
        if (_period > 0.5 days) revert OC_InvalidDisputePeriod();

        disputePeriod[_base][_quote] = _period;

        emit DisputePeriodUpdated(_base, _quote, _period);
    }
}
