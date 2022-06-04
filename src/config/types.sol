// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "./enums.sol";

/// @dev each margin position. This is used to store in storage
///
struct Account {
    uint256 shortCallId; // link to call or call spread
    uint256 shortPutId; // link to put or put spread
    uint64 shortCallAmount;
    uint64 shortPutAmount;
    uint80 collateralAmount;
    uint32 productId; // underlying - strike - collateral {?}
}

/// @dev struct used in memory to represnet a margin account's status
struct MarginAccountDetail {
    /// amounts, with 6 decimals
    uint256 putAmount;
    uint256 callAmount;
    /// strike prices in usd term, with 6 decimals.
    uint256 longPutStrike;
    uint256 shortPutStrike;
    uint256 longCallStrike;
    uint256 shortCallStrike;
    //
    uint256 expiry;
    uint256 collateralAmount;
    uint32 productId;
    bool isStrikeCollateral;
}

///
struct ActionArgs {
    ActionType action;
    bytes data;
}
