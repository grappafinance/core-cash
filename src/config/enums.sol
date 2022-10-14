// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum TokenType {
    PUT,
    PUT_SPREAD,
    CALL,
    CALL_SPREAD
}

enum ActionType {
    AddCollateral,
    RemoveCollateral,
    MintShort,
    BurnShort,
    MergeOptionToken,
    SplitOptionToken,
    AddLong,
    RemoveLong,
    SettleAccount,
    MintShortIntoAccount,
    TransferCollateral,
    TransferLong,
    TransferShort
}
