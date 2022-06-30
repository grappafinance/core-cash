// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// Errors
error NoAccess();

error InvalidSubAccountNumber();

error WrongProductId();

error WrongCollateralId();

error InvalidConfig();

error InvalidFromAddress();

error InvalidTokenId();

error AccountIsHealthy();

error AccountIsNotEmpty();

error WrongLiquidationAmounts();

error AccountUnderwater();

error NotExpired();

error WrongArgumentLength();

error WrongSettlementCollateral();

error CannotMergeSpread();

error MergeTypeMismatch();

error MergeProductMismatch();

error MergeExpiryMismatch();

error MergeWithSameStrike();

error CanOnlySplitSpread();

error WrongSplitId();

error SplitProductMismatch();

error SplitExpiryMismatch();

error Chainlink_AggregatorNotSet();

error Chainlink_StaleAnswer();

error Chainlink_RoundIdTooSmall();

// Oracle Errors

error OC_OnlyPricerCanWrite();

error OC_PriceNotReported();
