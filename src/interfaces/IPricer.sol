// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPricer {
    function getSpotPrice(address _base, address _quote) external view returns (uint256);
}
