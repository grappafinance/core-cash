// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

///@dev unit used for option amount and strike prices
uint256 constant UNIT = 1e6;

///@dev basic point for 100%.
uint256 constant BPS = 10000;

// constants for time value discout calculation

uint256 constant DISCOUNT_PERIOD_UPPER_BOUND = 180 days;
uint256 constant DISCOUNT_PERIOD_LOWER_BOND = 1 days;

uint256 constant SQRT_MAX_DISCOUNT_PERIOUD = 3944; // (86400*180).sqrt()
uint256 constant SQRT_MIN_DISCOUNT_PERIOUD = 293; // 86400.sqrt()
uint256 constant DIFF_SQRT_PERIOD = SQRT_MAX_DISCOUNT_PERIOUD -
    SQRT_MIN_DISCOUNT_PERIOUD;

/// @dev percentage of time value required as collateral when time to expiry is higher than upper bond
uint256 constant DISCOUNT_RATIO_UPPER_BOUND = 6400; // 64%
/// @dev percentage of time value required as collateral when time to expiry is lower than lower bond
uint256 constant DISCOUNT_RATIO_LOWER_BOUND = 800; // 8%
/// @dev difference between DISCOUNT_RATIO_UPPER_BOUND and DISCOUNT_RATIO_LOWER_BOUND
uint256 constant DIFF_DISCOUNT_RATIO = DISCOUNT_RATIO_UPPER_BOUND -
    DISCOUNT_RATIO_LOWER_BOUND;

uint256 constant SHOCK_RATIO = 1000; // 20%
