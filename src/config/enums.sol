// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

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
    SplitOptionToken,
    MergeOptionToken
}
