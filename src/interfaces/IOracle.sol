// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

interface IOracle {
    function getSpotPrice(address _underlying, address _strike) external view returns (uint256);

    function getPriceAtExpiry(
        address _underlying,
        address _strike,
        uint256 _expiry
    ) external view returns (uint256);
}
