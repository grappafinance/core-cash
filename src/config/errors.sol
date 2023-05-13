// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// for easier import
import "../core/oracles/errors.sol";

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

/// @dev put and call should not contain "short stirkes"
error GP_BadStrikes();

/// @dev burn or mint can only be called by corresponding engine.
error GP_Not_Authorized_Engine();

/* ---------------------------- *
 *   Common BaseEngine Errors   *
 * ---------------------------  */

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
