// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Types that should be defined in the margin engines
 * Defined here for testing purposes
 */

enum ActionType {
    AddCollateral,
    RemoveCollateral,
    MintShort,
    BurnShort,
    MergeOptionToken, // These actions are defined in "DebitSpread"
    SplitOptionToken, // These actions are defined in "DebitSpread"
    AddLong,
    RemoveLong,
    SettleAccount,
    // actions that influence more than one subAccounts:
    // These actions are defined in "OptionTransferable"
    MintShortIntoAccount, // increase short (debt) position in one subAccount, increase long token directly to another subAccount
    TransferCollateral, // transfer collateral directly to another subAccount
    TransferLong, // transfer long directly to another subAccount
    TransferShort, // transfer short directly to another subAccount
    BurnShortInAccount // decreases short position in one subAccount, decreases long position in another
}

struct ActionArgs {
    ActionType action;
    bytes data;
}

struct BatchExecute {
    address subAccount;
    ActionArgs[] actions;
}
