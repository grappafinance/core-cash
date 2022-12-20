// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* --------------------- *
 *  Cross Margin Errors
 * --------------------- */

/// @dev cross margin doesn't support this action
error CM_UnsupportedAction();

/// @dev cannot override a non-empty subaccount id
error CM_AccountIsNotEmpty();

/// @dev unsupported token type
error CM_UnsupportedTokenType();

/// @dev can only add long tokens that are not expired
error CM_Option_Expired();

/// @dev can only add long tokens from authorized engines
error CM_Not_Authorized_Engine();

/// @dev collateral id is wrong: the id doesn't match the existing collateral
error CM_WrongCollateralId();

/// @dev invalid collateral:
error CM_CannotMintOptionWithThisCollateral();

/// @dev invalid tokenId specify to mint / burn actions
error CM_InvalidToken();

/* --------------------- *
 *  Cross Margin Math Errors
 * --------------------- */

/// @dev invalid put length given strikes
error CMM_InvalidPutLengths();

/// @dev invalid call length given strikes
error CMM_InvalidCallLengths();

/// @dev invalid put length of zero
error CMM_InvalidPutWeight();

/// @dev invalid call length of zero
error CMM_InvalidCallWeight();
