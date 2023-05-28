// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ChainlinkOracle} from "./ChainlinkOracle.sol";

// constants and types
import "./errors.sol";
import "../../config/constants.sol";

/**
 * @title ChainlinkOracleDisputable
 * @author antoncoding
 * @dev chainlink oracle that can be dispute by the owner
 */
contract ChainlinkOracleDisputable is ChainlinkOracle {
    using SafeCastLib for uint256;

    // base => quote => dispute period
    mapping(address => mapping(address => uint256)) public disputePeriod;

    /*///////////////////////////////////////////////////////////////
                                 Events
    //////////////////////////////////////////////////////////////*/

    event DisputePeriodUpdated(address base, address quote, uint256 period);

    /**
     * @dev return the maximum dispute period for the oracle
     */
    function maxDisputePeriod() external pure override returns (uint256) {
        return MAX_DISPUTE_PERIOD;
    }

    /**
     * @dev view function to check if dispute period is over
     */
    function isExpiryPriceFinalized(address _base, address _quote, uint256 _expiry) external view returns (bool) {
        return _isExpiryPriceFinalized(_base, _quote, _expiry);
    }

    /**
     * @dev dispute an reported expiry price from the owner. Cannot dispute an un-reported price
     * @param _base base asset
     * @param _quote quote asset
     * @param _expiry expiry timestamp
     * @param _newPrice new price to set
     */
    function disputePrice(address _base, address _quote, uint256 _expiry, uint256 _newPrice) external onlyOwner {
        ExpiryPrice memory entry = expiryPrices[_base][_quote][_expiry];
        if (entry.reportAt == 0) revert OC_PriceNotReported();

        if (entry.isDisputed) revert OC_PriceDisputed();

        if (entry.reportAt + disputePeriod[_base][_quote] < block.timestamp) revert OC_DisputePeriodOver();

        expiryPrices[_base][_quote][_expiry] = ExpiryPrice(true, uint64(block.timestamp), _newPrice.safeCastTo128());

        emit ExpiryPriceSet(_base, _quote, _expiry, _newPrice, true);
    }

    /**
     * @dev owner can set a price if the the price has not been pushed for at least 36 hours
     * @param _base base asset
     * @param _quote quote asset
     * @param _expiry expiry timestamp
     * @param _price price to set
     */
    function setExpiryPriceBackup(address _base, address _quote, uint256 _expiry, uint256 _price) external onlyOwner {
        ExpiryPrice memory entry = expiryPrices[_base][_quote][_expiry];
        if (entry.reportAt != 0) revert OC_PriceReported();

        if (_expiry + 36 hours > block.timestamp) revert OC_GracePeriodNotOver();

        expiryPrices[_base][_quote][_expiry] = ExpiryPrice(true, uint64(block.timestamp), _price.safeCastTo128());

        emit ExpiryPriceSet(_base, _quote, _expiry, _price, true);
    }

    /**
     * @dev set the dispute period for a specific base / quote asset
     * @param _base base asset
     * @param _quote quote asset
     * @param _period dispute period. Cannot be set to a value longer than 6 hours
     */
    function setDisputePeriod(address _base, address _quote, uint256 _period) external onlyOwner {
        if (_period > MAX_DISPUTE_PERIOD) revert OC_InvalidDisputePeriod();

        disputePeriod[_base][_quote] = _period;

        emit DisputePeriodUpdated(_base, _quote, _period);
    }

    /**
     * @dev overrides _isExpiryPriceFinalized() from ChainlinkOracle to check if dispute period is over
     *      if true, getPriceAtExpiry will return (price, true)
     */
    function _isExpiryPriceFinalized(address _base, address _quote, uint256 _expiry) internal view override returns (bool) {
        ExpiryPrice memory entry = expiryPrices[_base][_quote][_expiry];
        if (entry.reportAt == 0) return false;

        if (entry.isDisputed) return true;

        return block.timestamp > entry.reportAt + disputePeriod[_base][_quote];
    }
}
