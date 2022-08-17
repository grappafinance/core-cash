// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// Errors

// Univeral Errors
error NoAccess();

// Erros in Grappa Contracts
error GP_Not_Authorized_Engine();

/// @dev amounts length speicified to batch settle doesn't match with tokenIds
error GP_WrongArgumentLength();

/// @dev cannot settle an unexpired option
error GP_NotExpired();

/// @dev account is not healthy / account is underwater
error GP_AccountUnderwater();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error GP_InvalidFromAddress();

// Advanced Margin and AdvancedMarginLib Errors

/// @dev collateral id is wrong: the id doesn't match the existing sub account
error AM_WrongCollateralId();

/// @dev can only merge subaccount with put or call.
error AM_CannotMergeSpread();

/// @dev existing short position in account doesn't match the incoming token
error AM_MergeTypeMismatch();

/// @dev existing product type in account doesn't match the incoming token
error AM_MergeProductMismatch();

/// @dev existing expiry in account doesn't match the incoming token
error AM_MergeExpiryMismatch();

/// @dev cannot merge type with the same strike. (should use burn instead)
error AM_MergeWithSameStrike();

/// @dev only spread position can be split
error AM_CanOnlySplitSpread();

/// @dev invalid tokenId specify to mint / burn actions
error AM_InvalidToken();

/// token id specified to liquidate mistmch vault debt
error AM_WrongIdToLiquidate();

/// @dev no config set for this asset.
error AM_NoConfig();

/// @dev cannot liquidate or takeover position: account is healthy
error AM_AccountIsHealthy();

/// @dev cannot override a non-empty subaccount id
error AM_AccountIsNotEmpty();

/// @dev amounts to repay in liquidation are not valid. Missing call, put or not proportional to the amount in subaccount.
error AM_WrongRepayAmounts();

// Chainlink Pricer Errors

error CL_AggregatorNotSet();

error CL_StaleAnswer();

error CL_RoundIdTooSmall();

// Oracle Errors

error OC_OnlyPricerCanWrite();

error OC_CannotReportForFuture();

error OC_PriceNotReported();
