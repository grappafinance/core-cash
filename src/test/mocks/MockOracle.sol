// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "src/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 public spotPrice;
    uint256 public expiryPrice;

    function getSpotPrice(
        address, /*_underlying*/
        address /*_strike*/
    ) external view returns (uint256) {
        return spotPrice;
    }

    function getPriceAtExpiry(
        address, /*_underlying*/
        address, /*_strike*/
        uint256 /*_expiry*/
    ) external view returns (uint256) {
        return expiryPrice;
    }

    function setSpotPrice(uint256 _mockedSpotPrice) external {
        spotPrice = _mockedSpotPrice;
    }

    function setExpiryPrice(uint256 _mockedExpiryPrice) external {
        expiryPrice = _mockedExpiryPrice;
    }
}
