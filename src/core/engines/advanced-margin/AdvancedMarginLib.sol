// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title AdvancedMarginLib
 * @dev   This library is in charge of updating the advanced account memory struct and do validation
 */
library AdvancedMarginLib {
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;

    /**
     * @dev return true if the account has no short positions nor collateral
     */
    function isEmpty(AdvancedMarginAccount storage account) internal view returns (bool) {
        return account.collateralAmount == 0 && account.shortCallAmount == 0 && account.shortPutAmount == 0;
    }

    ///@dev Increase the collateral in the account
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    function addCollateral(
        AdvancedMarginAccount storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        if (account.collateralId == 0) {
            account.collateralId = collateralId;
        } else {
            if (account.collateralId != collateralId) revert AM_WrongCollateralId();
        }
        account.collateralAmount += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    function removeCollateral(
        AdvancedMarginAccount storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        if (account.collateralId != collateralId) revert AM_WrongCollateralId();
        uint80 newAmount = account.collateralAmount - amount;
        account.collateralAmount = newAmount;
        if (newAmount == 0) {
            account.collateralId = 0;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    function mintOption(
        AdvancedMarginAccount storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (TokenType optionType, uint40 productId, , , ) = tokenId.parseTokenId();

        // assign collateralId or check collateral id is the same
        uint8 collateralId = productId.getCollateralId();
        if (account.collateralId == 0) {
            account.collateralId = collateralId;
        } else {
            if (account.collateralId != collateralId) revert AM_InvalidToken();
        }

        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // minting a short
            if (account.shortCallId == 0) account.shortCallId = tokenId;
            else if (account.shortCallId != tokenId) revert AM_InvalidToken();
            account.shortCallAmount += amount;
        } else {
            // minting a put or put spread
            if (account.shortPutId == 0) account.shortPutId = tokenId;
            else if (account.shortPutId != tokenId) revert AM_InvalidToken();
            account.shortPutAmount += amount;
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    function burnOption(
        AdvancedMarginAccount storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        TokenType optionType = tokenId.parseTokenType();
        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // burnning a call or call spread
            if (account.shortCallId != tokenId) revert AM_InvalidToken();
            account.shortCallAmount -= amount;
            if (account.shortCallAmount == 0) account.shortCallId = 0;
        } else {
            // burning a put or put spread
            if (account.shortPutId != tokenId) revert AM_InvalidToken();
            account.shortPutAmount -= amount;
            if (account.shortPutAmount == 0) account.shortPutId = 0;
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    ///@dev shortId and longId already have the same optionType, productId, expiry
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    ///@param shortId existing short position to be converted into spread
    ///@param longId token to be "added" into the account. This is expected to have the same time of the exisiting short type.
    ///               e.g: if the account currenly have short call, we can added another "call token" into the account
    ///               and convert the short position to a spread.
    function merge(
        AdvancedMarginAccount storage account,
        uint256 shortId,
        uint256 longId,
        uint64 amount
    ) internal {
        // get token attribute for incoming token
        (TokenType optionType, , , uint64 mergingStrike, ) = longId.parseTokenId();

        if (optionType == TokenType.CALL) {
            if (account.shortCallId != shortId) revert AM_ShortDoesnotExist();
            if (account.shortCallAmount != amount) revert AM_MergeAmountMisMatch();
            // adding the "strike of the adding token" to the "short strike" field of the existing "option token"
            account.shortCallId = TokenIdUtil.convertToSpreadId(shortId, mergingStrike);
        } else {
            // adding the "strike of the adding token" to the "short strike" field of the existing "option token"
            if (account.shortPutId != shortId) revert AM_ShortDoesnotExist();
            if (account.shortPutAmount != amount) revert AM_MergeAmountMisMatch();

            account.shortPutId = TokenIdUtil.convertToSpreadId(shortId, mergingStrike);
        }
    }

    ///@dev split an accunt's spread position into short + 1 token
    ///@param account AdvancedMarginAccount storage that will be updated in-place
    ///@param spreadId id of spread to be parsed
    function split(
        AdvancedMarginAccount storage account,
        uint256 spreadId,
        uint64 amount
    ) internal {
        // parse the passed in spread id
        TokenType spreadType = spreadId.parseTokenType();

        // check the existing short position
        bool isSplitingCallSpread = spreadType == TokenType.CALL_SPREAD;

        uint256 spreadIdInAccount = isSplitingCallSpread ? account.shortCallId : account.shortPutId;

        // passed in spreadId should match the one in account memory (shortCallId or shortPutId)
        if (spreadId != spreadIdInAccount) revert AM_InvalidToken();

        if (isSplitingCallSpread) {
            if (amount != account.shortCallAmount) revert AM_SplitAmountMisMatch();

            // convert to call: remove the "short strike" and update "tokenType" field
            account.shortCallId = TokenIdUtil.convertToVanillaId(spreadId);
        } else {
            if (amount != account.shortPutAmount) revert AM_SplitAmountMisMatch();
            // convert to put: remove the "short strike" and update "tokenType" field
            account.shortPutId = TokenIdUtil.convertToVanillaId(spreadId);
        }
    }

    function settleAtExpiry(AdvancedMarginAccount storage account, uint80 _payout) internal {
        // clear all debt
        account.shortPutId = 0;
        account.shortCallId = 0;
        account.shortCallAmount = 0;
        account.shortPutAmount = 0;

        if (account.collateralAmount > _payout) {
            unchecked {
                account.collateralAmount = account.collateralAmount - _payout;
            }
        } else {
            // the account doesn't have enough to payout, result in protocol loss
            account.collateralAmount = 0;
        }
    }
}
