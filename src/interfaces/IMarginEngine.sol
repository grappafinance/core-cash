// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarginEngine {
    function payCashValue(address _asset, address _recipient, uint256 _amount) external;
}
