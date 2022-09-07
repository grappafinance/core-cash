// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Errors

// Univeral Errors
error NoAccess();

// Erros in Grappa Contracts

/// @dev asset already registered
error GP_AssetAlreadyRegistered();

/// @dev margin engine already registered
error GP_EngineAlreadyRegistered();

/// @dev amounts length speicified to batch settle doesn't match with tokenIds
error GP_WrongArgumentLength();

/// @dev cannot settle an unexpired option
error GP_NotExpired();

// Common error in BaseMargin

/// @dev not supported action, only in base margin
error EG_UnsupportedAction();

/// @dev can only merge subaccount with put or call.
error BM_CannotMergeSpread();

/// @dev only spread position can be split
error BM_CanOnlySplitSpread();

/// @dev type of existing short token doesn't match the incoming token
error BM_MergeTypeMismatch();

/// @dev product type of existing short token doesn't match the incoming token
error BM_MergeProductMismatch();

/// @dev expiry of existing short token doesn't match the incoming token
error BM_MergeExpiryMismatch();

/// @dev cannot merge type with the same strike. (should use burn instead)
error BM_MergeWithSameStrike();

/// @dev account is not healthy / account is underwater
error BM_AccountUnderwater();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error BM_InvalidFromAddress();

// Fully Collateralized Margin

/// @dev full margin doesn't support this action
error FM_UnsupportedAction();

/// @dev invalid collateral:
///         call can only be collateralized by underlying
///         put can only be collateralized by strike
error FM_CannotMintOptionWithThisCollateral();

/// @dev collateral id is wrong: the id doesn't match the existing collateral
error FM_WrongCollateralId();

/// @dev invalid tokenId specify to mint / burn actions
error FM_InvalidToken();

/// @dev trying to merge an long with a non-existant short position
error FM_ShortDoesnotExist();

/// @dev can only merge same amount of long and short
error FM_MergeAmountMisMatch();

/// @dev can only split same amount of existing spread into short + long
error FM_SplitAmountMisMatch();

/// @dev trying to collateralized the position with different collateral than specified in productId
error FM_CollateraliMisMatch();

// Advanced Margin and AdvancedMarginLib Errors

/// @dev full margin doesn't support this action (add long and remove long)
error AM_UnsupportedAction();

/// @dev collateral id is wrong: the id doesn't match the existing collateral
error AM_WrongCollateralId();

/// @dev trying to merge an long with a non-existant short position
error AM_ShortDoesnotExist();

/// @dev can only merge same amount of long and short
error AM_MergeAmountMisMatch();

/// @dev can only split same amount of existing spread into short + long
error AM_SplitAmountMisMatch();

/// @dev invalid tokenId specify to mint / burn actions
error AM_InvalidToken();

/// @dev no config set for this asset.
error AM_NoConfig();

/// @dev cannot liquidate or takeover position: account is healthy
error AM_AccountIsHealthy();

/// @dev cannot override a non-empty subaccount id
error AM_AccountIsNotEmpty();

/// @dev amounts to repay in liquidation are not valid. Missing call, put or not proportional to the amount in subaccount.
error AM_WrongRepayAmounts();

// OptionToken

/// @dev burn or mint can only be called by corresponding engine.
error OT_Not_Authorized_Engine();

/// @dev cannot mint token after expiry
error OT_InvalidExpiry();

/// @dev put and call should not contain "short stirkes"
error OT_BadStrikes();

// Chainlink Pricer Errors

error CL_AggregatorNotSet();

error CL_StaleAnswer();

error CL_RoundIdTooSmall();

// Oracle Errors

error OC_OnlyPricerCanWrite();

error OC_CannotReportForFuture();

error OC_PriceNotReported();

// Vol Oracle

error VO_AggregatorAlreadySet();

error VO_AggregatorNotSet();
