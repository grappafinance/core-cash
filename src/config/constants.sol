// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

///@dev unit used for option amount and strike prices
uint8 constant UNIT_DECIMALS = 6;

///@dev unit scaled used to convert amounts.
uint256 constant UNIT = 10**6;
int256 constant sUNIT = int256(10**6);

///@dev basis point for 100%.
uint256 constant BPS = 10000;

uint256 constant ZERO = 0;
int256 constant sZERO = int256(0);

///@dev maximum dispute period for oracle
uint256 constant MAX_DISPUTE_PERIOD = 6 hours;
