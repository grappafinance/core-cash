// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

///@dev unit used for option amount and strike prices
uint8 constant UNIT_DECIMALS = 6;
uint256 constant UNIT = 10**UNIT_DECIMALS;
int256 constant sUNIT = int256(UNIT);

///@dev basic point for 100%.
uint256 constant BPS = 10000;

uint256 constant ZERO = 0;
int256 constant sZERO = 0;
