// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "src/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    uint256 public spotPrice;
    uint256 public expiryPrice;
    uint256 public vol = 1e6;

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

    function getVolIndex() external view returns (uint256) {
        return vol;
    }

    function setSpotPrice(uint256 _mockedSpotPrice) external {
        spotPrice = _mockedSpotPrice;
    }

    function setExpiryPrice(uint256 _mockedExpiryPrice) external {
        expiryPrice = _mockedExpiryPrice;
    }

     function setVol(uint256 _vol) external {
        vol = _vol;
    }

    function reportExpiryPrice(
        address /**_base**/,
        address /**_quote**/,
        uint256 /**_expiry**/,
        uint256 _price
    ) external {
        expiryPrice = _price;
    }
}
