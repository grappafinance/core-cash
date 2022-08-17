// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

interface IOracle {
    function getSpotPrice(address _base, address _quote) external view returns (uint256);

    function getPriceAtExpiry(
        address _base,
        address _quote,
        uint256 _expiry
    ) external view returns (uint256);

    function reportExpiryPrice(
        address _base,
        address _quote,
        uint256 _expiry,
        uint256 _price
    ) external;
}
