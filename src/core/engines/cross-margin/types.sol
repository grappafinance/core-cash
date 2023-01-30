// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../config/enums.sol";
import "../../../config/types.sol";

/**
 * @dev base unit of cross margin account. This is the data stored in the state
 *      storage packing is utilized to save gas.
 * @param shorts an array of short positions
 * @param longs an array of long positions
 * @param collaterals an array of collateral balances
 */
struct CrossMarginAccount {
    Position[] shorts;
    Position[] longs;
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
    uint256 expiry;
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
