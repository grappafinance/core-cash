// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "./enums.sol";

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
struct Account {
    uint256 shortCallId;
    uint256 shortPutId;
    uint64 shortCallAmount;
    uint64 shortPutAmount;
    uint80 collateralAmount;
    uint8 collateralId;
}

/**
 * @dev struct used in memory to represnet a margin account's status
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
struct MarginAccountDetail {
    uint256 callAmount;
    uint256 putAmount;
    uint256 longCallStrike;
    uint256 shortCallStrike;
    uint256 longPutStrike;
    uint256 shortPutStrike;
    uint256 expiry;
    uint256 collateralAmount;
    uint32 productId;
}

/**
 * @dev struct containing assets detail for an product
 * @param underlying    underlying address
 * @param strike        strike address
 * @param collateral    collateral address
 * @param collateralDecimals collateral asset decimals
 */
struct ProductAssets {
    address underlying;
    address strike;
    address collateral;
    uint8 collateralDecimals;
}

// todo: update doc after adopting new formula
struct ProductMarginParams {
    uint32 discountPeriodUpperBound; // = 180 days;
    uint32 discountPeriodLowerBound; // = 1 days;
    uint32 sqrtMaxDiscountPeriod; // = 3944; // (86400*180).sqrt()
    uint32 sqrtMinDiscountPeriod; // 293; // 86400.sqrt()
    /// @dev percentage of time value required as collateral when time to expiry is higher than upper bond
    uint32 discountRatioUpperBound; // = 6400; // 64%
    /// @dev percentage of time value required as collateral when time to expiry is lower than lower bond
    uint32 discountRatioLowerBound; // = 800; // 8%
    uint32 volMultiplier;
}

// todo: update doc
struct ActionArgs {
    ActionType action;
    bytes data;
}

/**
 * @dev asset detail stored per asset id
 * @param addr use uint160 to store address so it can be packed with decimals
 * @param decimals token decimals
 */
struct AssetDetail {
    uint160 addr;
    uint8 decimals;
}
