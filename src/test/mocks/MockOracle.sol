// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    mapping(address => uint256) public spotPrice;
    mapping(address => mapping(address => uint256)) public expiryPrice;
    mapping(address => mapping(address => bool)) public isNotFinalized;

    function getSpotPrice(
        address _underlying,
        address /*_strike*/
    ) external view override returns (uint256) {
        return spotPrice[_underlying];
    }

    function getPriceAtExpiry(
        address base,
        address quote,
        uint256 /*_expiry*/
    ) external view override returns (uint256) {
        return expiryPrice[base][quote];
    }

    function isExpiryPriceFinalized(address _base, address _quote, uint256) external view returns (bool) {
        // default to yes, revert if set to true
        return (!isNotFinalized[_base][_quote]);
    }

    function setSpotPrice(address _asset, uint256 _mockedSpotPrice) external {
        spotPrice[_asset] = _mockedSpotPrice;
    }

    function setExpiryPrice(
        address base,
        address quote,
        uint256 _mockedExpiryPrice
    ) external {
        expiryPrice[base][quote] = _mockedExpiryPrice;
    }
}
