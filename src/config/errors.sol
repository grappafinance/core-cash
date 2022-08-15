// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// Errors

// Univeral Errors
error NoAccess();

// Grappa Main
error Not_Authorized_Engine();

// Margin Account Errors

/// token id specified to liquidate mistmch vault debt
error MA_WrongIdToLiquidate();

/// @dev collateral id is wrong: the id doesn't match the existing sub account
error AM_WrongCollateralId();

/// @dev no config set for this asset.
error MA_NoConfig();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error MA_InvalidFromAddress();

/// @dev invalid tokenId specify to mint / burn actions
error AM_InvalidToken();

/// @dev cannot liquidate or takeover position: account is healthy
error MA_AccountIsHealthy();

/// @dev account is not healthy / account is underwater
error MA_AccountUnderwater();

/// @dev cannot override a non-empty subaccount id
error MA_AccountIsNotEmpty();

/// @dev amounts to repay in liquidation are not valid. Missing call, put or not proportional to the amount in subaccount.
error MA_WrongRepayAmounts();

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

/// @dev cannot settle an unexpired option
error MA_NotExpired();

// Erros in Settlement Contract

/// @dev amounts length speicified to batch settle doesn't match with tokenIds
error ST_WrongArgumentLength();

/// @dev cannot settle multiple options with different collateral at once
error ST_WrongSettlementCollateral();

// Chainlink Pricer Errors

error CL_AggregatorNotSet();

error CL_StaleAnswer();

error CL_RoundIdTooSmall();

// Oracle Errors

error OC_OnlyPricerCanWrite();

error OC_CannotReportForFuture();

error OC_PriceNotReported();
