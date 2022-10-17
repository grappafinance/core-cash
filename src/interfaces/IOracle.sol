// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function getSpotPrice(address _base, address _quote) external view returns (uint256);

    function getPriceAtExpiry(
        address _base,
        address _quote,
        uint256 _expiry
    ) external view returns (uint256 price, bool isFinalized);
}
