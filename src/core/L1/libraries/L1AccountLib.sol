// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "src/libraries/OptionTokenUtils.sol";

import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

/**
 * @title L1AccountLib
 * @dev   This library is in charge of updating the l1 account memory and do validations
 */
library L1AccountLib {
    ///@dev Increase the collateral in the account
    ///@param account Account memory that will be updated in-place
    function addCollateral(
        Account memory account,
        uint80 amount,
        uint32 productId
    ) internal pure {
        if (account.productId == 0) {
            account.productId = productId;
        } else {
            if (account.productId != productId) revert WrongProductId();
        }
        account.collateralAmount += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account Account memory that will be updated in-place
    function removeCollateral(Account memory account, uint80 amount) internal pure {
        account.collateralAmount -= amount;
        if (account.collateralAmount == 0) {
            account.productId = 0;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account Account memory that will be updated in-place
    function mintOption(
        Account memory account,
        uint256 tokenId,
        uint64 amount
    ) internal pure {
        (TokenType optionType, , , uint64 tokenLongStrike, uint64 tokenShortStrike) = OptionTokenUtils.parseTokenId(
            tokenId
        );

        // check that vanilla options doesnt have a shortStrike argument
        if ((optionType == TokenType.CALL || optionType == TokenType.PUT) && (tokenShortStrike != 0))
            revert InvalidTokenId();
        // check that you cannot mint a "credit spread" token
        if (optionType == TokenType.CALL_SPREAD && (tokenShortStrike < tokenLongStrike)) revert InvalidTokenId();
        if (optionType == TokenType.PUT_SPREAD && (tokenShortStrike > tokenLongStrike)) revert InvalidTokenId();

        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // minting a short
            if (account.shortCallId == 0) account.shortCallId = tokenId;
            else if (account.shortCallId != tokenId) revert InvalidTokenId();
            account.shortCallAmount += amount;
        } else {
            // minting a put or put spread
            if (account.shortPutId == 0) account.shortPutId = tokenId;
            else if (account.shortPutId != tokenId) revert InvalidTokenId();
            account.shortPutAmount += amount;
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account Account memory that will be updated in-place
    function burnOption(
        Account memory account,
        uint256 tokenId,
        uint64 amount
    ) internal pure {
        TokenType optionType = OptionTokenUtils.parseTokenType(tokenId);
        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // burnning a call or call spread
            if (account.shortCallId != tokenId) revert InvalidTokenId();
            account.shortCallAmount -= amount;
            if (account.shortCallAmount == 0) account.shortCallId = 0;
        } else {
            // burning a put or put spread
            if (account.shortPutId != tokenId) revert InvalidTokenId();
            account.shortPutAmount -= amount;
            if (account.shortPutAmount == 0) account.shortPutId = 0;
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    ///@param account Account memory that will be updated in-place
    ///@param tokenId token to be "added" into the account. This is expected to have the same time of the exisiting short type.
    ///               e.g: if the account currenly have short call, we can added another "call token" into the account
    ///               and convert the short position to a spread.
    function merge(
        Account memory account,
        uint256 tokenId,
        uint64 amount
    ) internal pure {
        // get token attribute for incoming token
        (TokenType optionType, uint32 productId, uint64 expiry, uint64 mergingStrike, ) = OptionTokenUtils.parseTokenId(
            tokenId
        );

        // token being added can only be call or put
        if (optionType != TokenType.CALL && optionType != TokenType.PUT) revert CannotMergeSpread();

        // check the existing short position
        bool isMergingCall = optionType == TokenType.CALL;
        uint256 shortId = isMergingCall ? account.shortCallId : account.shortPutId;
        uint256 shortAmount = isMergingCall ? account.shortCallAmount : account.shortPutAmount;

        (TokenType shortType, uint32 productId_, uint64 expiry_, uint64 tokenLongStrike_, ) = OptionTokenUtils
            .parseTokenId(shortId);

        // if exisiting type is SPREAD, will revert
        if (shortType != optionType) revert MergeTypeMismatch();

        if (productId_ != productId) revert MergeProductMismatch();
        if (expiry_ != expiry) revert MergeExpiryMismatch();
        if (shortAmount != amount) revert MergeAmountMismatch();

        if (tokenLongStrike_ == mergingStrike) revert MergeWithSameStrike();

        if (optionType == TokenType.CALL) {
            // adding the "strike of the adding token" to the "long strike" field of the existing "option token"
            account.shortCallId = account.shortCallId + mergingStrike;
        } else {
            // adding the "strike of the adding token" to the "long strike" field of the existing "option token"
            account.shortPutId = account.shortPutId + mergingStrike;
        }
    }

    ///@dev split an MarginAccount with spread into short + long
    ///@param account Account memory that will be updated in-place
    function split(Account memory account, bytes memory _data) internal {}
}
