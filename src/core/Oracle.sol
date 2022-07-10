// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// interfaces
import {IOracle} from "src/interfaces/IOracle.sol";
import {IPricer} from "src/interfaces/IPricer.sol";

// constants and types
import "src/config/errors.sol";

/**
 * @title Oracle
 * @author @antoncoding
 * @dev return base / quote price, with 6 decimals
 * @dev return vol index, with 6 decimalss
 */
contract Oracle is IOracle {
    struct ExpiryPrice {
        bool reported;
        uint128 price;
    }

    IPricer public immutable primaryPricer;
    IPricer public immutable secondaryPricer;

    ///@dev base => quote => expiry => price.
    mapping(address => mapping(address => mapping(uint256 => ExpiryPrice))) public expiryPrices;

    constructor(address _primaryPricer, address _secondaryPricer) {
        primaryPricer = IPricer(_primaryPricer);
        secondaryPricer = IPricer(_secondaryPricer);
    }

    /**
     * @notice  get spot price of _base, denominated in _quote.
     *
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     *
     * @return price with 6 decimals
     */
    function getSpotPrice(address _base, address _quote) external view override returns (uint256) {
        try primaryPricer.getSpotPrice(_base, _quote) returns (uint256 price) {
            return price;
        } catch (
            bytes memory /*lowLevelData*/
        ) {
            // catch any error from primary pricer, and fallback to secondary pricer
            return secondaryPricer.getSpotPrice(_base, _quote);
        }
    }

    /**
     * @dev get expiry price of underlying, denominated in strike asset.
            can revert if expiry is in the future, or the price has not been reported by authorized party
     *
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @param _expiry expiry timestamp
     *
     * @return price with 6 decimals
     */
    function getPriceAtExpiry(
        address _base,
        address _quote,
        uint256 _expiry
    ) external view returns (uint256 price) {
        ExpiryPrice memory data = expiryPrices[_base][_quote][_expiry];
        if (!data.reported) revert OC_PriceNotReported();

        return data.price;
    }

    /**
     * @dev report expiry price. Should only be called by the 2 pricers
     *
     * @param _base base asset. for ETH/USD price, ETH is the base asset
     * @param _quote quote asset. for ETH/USD price, USD is the quote asset
     * @param _expiry expiry timestamp
     * @param _price price in 6 decimals
     *
     */
    function reportExpiryPrice(
        address _base,
        address _quote,
        uint256 _expiry,
        uint256 _price
    ) external {
        if (msg.sender != address(primaryPricer) && msg.sender != address(secondaryPricer))
            revert OC_OnlyPricerCanWrite();

        // revert when trying to set price for the future
        if (_expiry > block.timestamp) revert OC_CannotReportForFuture();

        //todo: safeCast to be extra safe
        expiryPrices[_base][_quote][_expiry] = ExpiryPrice(true, uint128(_price));
    }

    /**
     * @dev get volatility index
     */
    function getVolIndex() external pure returns (uint256) {
        return 1 * 1e6;
    }
}
