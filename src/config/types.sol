// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./enums.sol";

struct FullMarginAccount {
    uint256 tokenId;
    uint64 shortAmount;
    uint8 collateralId;
    uint80 collateralAmount;
}

struct FullMarginDetail {
    uint256 shortAmount;
    uint256 longStrike;
    uint256 shortStrike;
    uint256 collateralAmount;
    uint8 collateralDecimals;
    bool collateralizedWithStrike;
    TokenType tokenType;
}

/**
 * @dev base unit of cross margin account. This is the data stored in the state
 *      storage packing is utilized to save gas.
 * @param shorts an array of short positions
 * @param longs an array of long positions
 * @param collaterals an array of collateral balances
 */
struct CrossMarginAccount {
    PositionOptim[] shorts;
    PositionOptim[] longs;
    Balance[] collaterals;
}

/**
 * @dev struct used in memory to represent a cross margin account's option set
 *      this is a grouping of like underlying, collateral, strike (asset), and expiry
 *      used to calculate margin requirements
 * @param putWeights            amount of put options held in account (shorts and longs)
 * @param putStrikes            strikes of put options held in account (shorts and longs)
 * @param callWeights           amount of call options held in account (shorts and longs)
 * @param callStrikes           strikes of call options held in account (shorts and longs)
 * @param underlyingId          grappa id for underlying asset
 * @param underlyingDecimals    decimal points of underlying asset
 * @param numeraireId           grappa id for numeraire (aka strike) asset
 * @param numeraireDecimals     decimal points of numeraire (aka strike) asset
 * @param spotPrice             current spot price of underlying in terms of strike asset
 * @param expiry                expiry of the option
 */
struct CrossMarginDetail {
    int256[] putWeights;
    uint256[] putStrikes;
    int256[] callWeights;
    uint256[] callStrikes;
    uint8 underlyingId;
    uint8 underlyingDecimals;
    uint8 numeraireId;
    uint8 numeraireDecimals;
    uint256 spotPrice;
    uint256 expiry;
}

/**
 * @dev a compressed Position struct, compresses tokenId to save storage space
 * @param tokenId option token
 * @param amount number option tokens
 */
struct PositionOptim {
    uint192 tokenId;
    uint64 amount;
}

/**
 * @dev an uncompressed Position struct, expanding tokenId to uint256
 * @param tokenId grappa option token id
 * @param amount number option tokens
 */
struct Position {
    uint256 tokenId;
    uint64 amount;
}

/**
 * @dev struct representing the current balance for a given collateral
 * @param collateralId grappa asset id
 * @param amount amount the asset
 */
struct Balance {
    uint8 collateralId;
    uint80 amount;
}

/**
 * @dev base unit of margin account. This is the data stored in the state
 *      storage packing is utilized to save gas.
 * @param shortCallId tokenId for the call minted. Could be call or call spread
 * @param shortPutId tokenId for the put minted. Could be put or put spread
 * @param shortCallAmount amount of call minted. with 6 decimals
 * @param shortPutAmount amount of put minted. with 6 decimals
 * @param collateralAmount amount of collateral deposited
 * @param collateralId id of collateral
 */
struct AdvancedMarginAccount {
    uint256 shortCallId;
    uint256 shortPutId;
    uint64 shortCallAmount;
    uint64 shortPutAmount;
    uint80 collateralAmount;
    uint8 collateralId;
}

/**
 * @dev struct used in memory to represent a margin account's status
 *      all these data can be derived from Account struct
 * @param callAmount        amount of call minted
 * @param putAmount         amount of put minted
 * @param longCallStrike    the strike of call the account is long, only present if account minted call spread
 * @param shortCallStrike   the strike of call the account is short, only present if account minted call (or call spread)
 * @param longPutStrike     the strike of put the account is long, only present if account minted put spread
 * @param shortPutStrike    the strike of put the account is short, only present if account minted put (or call spread)
 * @param expiry            expiry of the call or put. if call and put have different expiry,
                            they should not be able to be put into the same account
 * @param collateralAmount  amount of collateral in its native token decimal
 * @param productId         uint32 number representing the productId.
 */
struct AdvancedMarginDetail {
    uint256 callAmount;
    uint256 putAmount;
    uint256 longCallStrike;
    uint256 shortCallStrike;
    uint256 longPutStrike;
    uint256 shortPutStrike;
    uint256 expiry;
    uint256 collateralAmount;
    uint40 productId;
}

/**
 * @dev struct containing assets detail for an product
 * @param underlying    underlying address
 * @param strike        strike address
 * @param collateral    collateral address
 * @param collateralDecimals collateral asset decimals
 */
struct ProductDetails {
    address oracle;
    uint8 oracleId;
    address engine;
    uint8 engineId;
    address underlying;
    uint8 underlyingId;
    uint8 underlyingDecimals;
    address strike;
    uint8 strikeId;
    uint8 strikeDecimals;
    address collateral;
    uint8 collateralId;
    uint8 collateralDecimals;
}

/**
 * @notice  parameters for calculating min collateral for a specific product
 * @dev     this formula and parameter struct is used for AdvancedMargin
 *
 *                  sqrt(expiry - now) - sqrt(D_lower)
 * M = (r_lower + -------------------------------------  * (r_upper - r_lower))  * vol + v_multiplier
 *                     sqrt(D_upper) - sqrt(D_lower)
 *
 *                                s^2
 * min_call (s, k) = M * min (s, ----- * max(v, 1), k ) + max (0, s - k)
 *                                 k
 *
 *                                k^2
 * min_put (s, k)  = M * min (s, ----- * max(v, 1), k ) + max (0, k - s)
 *                                 s
 * @param dUpper discountPeriodUpperBound (D_upper)
 * @param dLower discountPeriodLowerBound (D_lower)
 * @param sqrtDUpper stored dUpper.sqrt() to save gas
 * @param sqrtDLower
 * @param rUpper (r_upper) percentage in BPS, how much discount if higher than dUpper (min discount)
 * @param rLower (r_lower) percentage in BPS, how much discount if lower than dLower (max discount)
 * @param volMultiplier percentage in BPS showing how much vol should be derived from vol index
 *
 */
struct ProductMarginParams {
    uint32 dUpper;
    uint32 dLower;
    uint32 sqrtDUpper;
    uint32 sqrtDLower;
    uint32 rUpper;
    uint32 rLower;
    uint32 volMultiplier;
}

// todo: update doc
struct ActionArgs {
    ActionType action;
    bytes data;
}

struct BatchExecute {
    address subAccount;
    ActionArgs[] actions;
}

/**
 * @dev asset detail stored per asset id
 * @param addr address of the asset
 * @param decimals token decimals
 */
struct AssetDetail {
    address addr;
    uint8 decimals;
}
