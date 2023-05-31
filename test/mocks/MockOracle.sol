// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    struct MockPrice {
        uint128 price;
        bool isFinalized;
    }

    mapping(address => uint256) public spotPrice;
    mapping(address => mapping(address => MockPrice)) public expiryPrice;

    uint256 private disputePeriod;

    function maxDisputePeriod() external view override returns (uint256) {
        return disputePeriod;
    }

    function getSpotPrice(address _underlying, address /*_strike*/ ) external view override returns (uint256) {
        return spotPrice[_underlying];
    }

    function getPriceAtExpiry(address base, address quote, uint256 /*_expiry*/ ) external view override returns (uint256, bool) {
        MockPrice memory p = expiryPrice[base][quote];
        return (p.price, p.isFinalized);
    }

    function setViewDisputePeriod(uint256 _period) external {
        disputePeriod = _period;
    }

    function setSpotPrice(address _asset, uint256 _mockedSpotPrice) external {
        spotPrice[_asset] = _mockedSpotPrice;
    }

    function setExpiryPrice(address base, address quote, uint256 _mockedExpiryPrice) external {
        expiryPrice[base][quote] = MockPrice(uint128(_mockedExpiryPrice), true);
    }

    function setExpiryPriceWithFinality(address base, address quote, uint256 _mockedExpiryPrice, bool _isFinalized) external {
        expiryPrice[base][quote] = MockPrice(uint128(_mockedExpiryPrice), _isFinalized);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
