// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

enum ActionType {
    AddCollateral,
    RemoveCollateral,
    MintShort,
    BurnShort,
    SplitOptionToken,
    MergeOptionToken
}
