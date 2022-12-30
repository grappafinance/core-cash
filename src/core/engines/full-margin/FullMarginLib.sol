// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";

import "../../../config/constants.sol";

// Full margin types
import "./types.sol";
import "./errors.sol";

/**
 * @title FullMarginLib
 * @dev   This library is in charge of updating the full account struct.
 *        whether a "token id" is valid or not is checked in Grappa.sol.
 *
 *        FullMarginLib only supports 1 collat type and 1 short position
 */
library FullMarginLib {
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;

    /**
     * @dev return true if the account has no short positions nor collateral
     */
    function isEmpty(FullMarginAccount storage account) internal view returns (bool) {
        return account.collateralAmount == 0 && account.shortAmount == 0;
    }

    ///@dev Increase the collateral in the account
    ///@param account FullMarginAccount memory that will be updated
    function addCollateral(FullMarginAccount storage account, uint8 collateralId, uint80 amount) internal {
        uint80 cacheId = account.collateralId;
        if (cacheId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheId != collateralId) revert FM_WrongCollateralId();
        }
        account.collateralAmount += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account FullMarginAccount storage that will be updated
    function removeCollateral(FullMarginAccount storage account, uint8 collateralId, uint80 amount) internal {
        if (account.collateralId != collateralId) revert FM_WrongCollateralId();

        uint80 newAmount = account.collateralAmount - amount;
        account.collateralAmount = newAmount;
        if (newAmount == 0) {
            account.collateralId = 0;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account FullMarginAccount storage that will be updated
    function mintOption(FullMarginAccount storage account, uint256 tokenId, uint64 amount) internal {
        (TokenType tokenType,, uint40 productId,,,) = tokenId.parseTokenId();

        // assign collateralId or check collateral id is the same
        (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = productId.parseProductId();

        // call can only collateralized by underlying
        if ((tokenType == TokenType.CALL) && underlyingId != collateralId) {
            revert FM_CannotMintOptionWithThisCollateral();
        }

        // call spread can be collateralized by underlying or strike
        if (tokenType == TokenType.CALL_SPREAD && collateralId != underlyingId && collateralId != strikeId) {
            revert FM_CannotMintOptionWithThisCollateral();
        }

        // put or put spread can only be collateralized by strike
        if ((tokenType == TokenType.PUT_SPREAD || tokenType == TokenType.PUT) && strikeId != collateralId) {
            revert FM_CannotMintOptionWithThisCollateral();
        }

        uint80 cacheCollatId = account.collateralId;
        if (cacheCollatId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheCollatId != collateralId) revert FM_CollateraliMisMatch();
        }

        uint256 cacheTokenId = account.tokenId;
        if (cacheTokenId == 0) account.tokenId = tokenId;
        else if (cacheTokenId != tokenId) revert FM_InvalidToken();

        account.shortAmount += amount;
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account FullMarginAccount memory that will be updated in-place
    function burnOption(FullMarginAccount storage account, uint256 tokenId, uint64 amount) internal {
        if (account.tokenId != tokenId) revert FM_InvalidToken();

        uint64 newShortAmount = account.shortAmount - amount;
        if (newShortAmount == 0) account.tokenId = 0;
        account.shortAmount = newShortAmount;
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    ///@dev shortId and longId already have the same tokenType, productId, expiry
    ///@param account FullMarginAccount storage that will be updated
    ///@param shortId existing short position to be converted into spread
    ///@param longId token to be "added" into the account. This is expected to have the same time of the exisiting short type.
    ///               e.g: if the account currenly have short call, we can added another "call token" into the account
    ///               and convert the short position to a spread.
    function merge(FullMarginAccount storage account, uint256 shortId, uint256 longId, uint64 amount) internal {
        // get token attribute for incoming token
        (,,,, uint64 mergingStrike,) = longId.parseTokenId();

        if (account.tokenId != shortId) revert FM_ShortDoesnotExist();
        if (account.shortAmount != amount) revert FM_MergeAmountMisMatch();

        // this can make the vault in either credit spread of debit spread position
        account.tokenId = TokenIdUtil.convertToSpreadId(shortId, mergingStrike);
    }

    ///@dev split an accunt's spread position into short + 1 token
    ///@param account FullMarginAccount storage that will be updated
    ///@param spreadId id of spread to be parsed
    function split(FullMarginAccount storage account, uint256 spreadId, uint64 amount) internal {
        // passed in spreadId should match the one in account memory (shortCallId or shortPutId)
        if (spreadId != account.tokenId) revert FM_InvalidToken();
        if (amount != account.shortAmount) revert FM_SplitAmountMisMatch();

        // convert to call: remove the "short strike" and update "tokenType" field
        account.tokenId = TokenIdUtil.convertToVanillaId(spreadId);
    }

    /**
     * @dev clear short amount, and reduce collateral ny amount of payout
     * @param account FullMarginAccount storage that will be updated
     * @param payout amount of payout for minted options
     */
    function settleAtExpiry(FullMarginAccount storage account, uint80 payout) internal {
        // clear all debt
        account.tokenId = 0;
        account.shortAmount = 0;

        // this line should not underflow because collateral should always be enough
        // but keeping the underflow check to make sure
        account.collateralAmount = account.collateralAmount - payout;

        // do not check ending collateral amount (and reset collateral id) because it is very
        // unlikely the payou is the exact amount in the account
        // if that is the case (collateralAmount = 0), use can use removeCollateral(0)
        // to reset the collateral id
    }
}
