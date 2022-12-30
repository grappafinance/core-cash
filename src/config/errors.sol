// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// for easier import
import "../core/oracles/errors.sol";
import "../core/engines/full-margin/errors.sol";
import "../core/engines/advanced-margin/errors.sol";
import "../core/engines/cross-margin/errors.sol";

/* ------------------------ *
 *      Shared Errors       *
 * -----------------------  */

error NoAccess();

/* ------------------------ *
 *      Grappa Errors       *
 * -----------------------  */

/// @dev asset already registered
error GP_AssetAlreadyRegistered();

/// @dev margin engine already registered
error GP_EngineAlreadyRegistered();

/// @dev oracle already registered
error GP_OracleAlreadyRegistered();

/// @dev registring oracle doesn't comply with the max dispute period constraint.
error GP_BadOracle();

/// @dev amounts length speicified to batch settle doesn't match with tokenIds
error GP_WrongArgumentLength();

/// @dev cannot settle an unexpired option
error GP_NotExpired();

/// @dev settlement price is not finalized yet
error GP_PriceNotFinalized();

/// @dev cannot mint token after expiry
error GP_InvalidExpiry();

/// @dev put and call should not contain "short strikes"
error GP_BadCashSettledStrikes();

/// @dev put and call should not contain "short strikes"
error GP_BadPhysicalSettlementToken();

/// @dev burn or mint can only be called by corresponding engine.
error GP_Not_Authorized_Engine();

/* ---------------------------- *
 *   Common BaseEngine Errors   *
 * ---------------------------  */

/// @dev can only merge subaccount with put or call.
error BM_CannotMergeSpread();

/// @dev only spread position can be split
error BM_CanOnlySplitSpread();

/// @dev account is not healthy / account is underwater
error BM_AccountUnderwater();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error BM_InvalidFromAddress();

/// @dev invalid settlement type
error BM_InvalidSettlementType();

/* ----------------------------- *
 *      Debit Spreads Errors     *
 * ----------------------------- */

/// @dev type of existing short token type doesn't match the incoming token type
error DS_MergeOptionTypeMismatch();

/// @dev type of existing short token type doesn't match the incoming token type
error DS_MergeSettlementTypeMismatch();

/// @dev product type of existing short token doesn't match the incoming token
error DS_MergeProductMismatch();

/// @dev expiry of existing short token doesn't match the incoming token
error DS_MergeExpiryMismatch();

/// @dev cannot merge type with the same strike. (should use burn instead)
error DS_MergeWithSameStrike();

/* ----------------------------- *
 *   Physcially Settled Errors   *
 * ----------------------------- */

/// @dev issuer already registered
error PS_IssuerAlreadyRegistered();

/// @dev invalid settlement type
error PS_InvalidSettlementType();

/// @dev invalid issuer address in token
error PS_InvalidIssuerAddress();

error PS_InvalidSettlementWindow();
