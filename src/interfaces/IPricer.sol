// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

interface IPricer {
    function getSpotPrice(address _base, address _quote) external view returns (uint256);
}
