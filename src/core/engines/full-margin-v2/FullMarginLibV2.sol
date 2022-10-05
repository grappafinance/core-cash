// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";
import {LinkedList} from "../../../libraries/LinkedList.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "forge-std/console2.sol";

/**
 * @title FullMarginLib
 * @dev   This library is in charge of updating the simple account memory struct and do validations
 */
library FullMarginLibV2 {
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;
    using LinkedList for LinkedList.ListWithAmount;

    /**
     * @dev return true if the account has no short positions nor collateral
     */
    function isEmpty(FullMarginAccountV2 storage account) internal view returns (bool) {
        return (account.collateralAmount == 0 &&
            account.shortPuts.size == 0 &&
            account.longPuts.size == 0 &&
            account.shortCalls.size == 0 &&
            account.longCalls.size == 0);
    }

    ///@dev Increase the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function addCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        uint80 cacheId = account.collateralId;
        if (cacheId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheId != collateralId) revert FM_WrongCollateralId();
        }
        account.collateralAmount += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function removeCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        if (account.collateralId != collateralId) revert FM_WrongCollateralId();

        uint80 newAmount = account.collateralAmount - amount;
        account.collateralAmount = newAmount;
        if (newAmount == 0) {
            account.collateralId = 0;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function mintOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (TokenType optionType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = tokenId
            .parseTokenId();

        _verifyAndSetAccountInfo(account, productId, expiry);

        if (optionType == TokenType.CALL) {
            _addIntoSortedListAndIncreaseAmount(account.shortCalls, true, longStrike, amount);
        } else if (optionType == TokenType.PUT) {
            _addIntoSortedListAndIncreaseAmount(account.shortPuts, false, longStrike, amount);
        } else if (optionType == TokenType.CALL_SPREAD) {
            _addIntoSortedListAndIncreaseAmount(account.shortCalls, true, longStrike, amount);
            _addIntoSortedListAndIncreaseAmount(account.longCalls, true, shortStrike, amount);
        } else if (optionType == TokenType.PUT_SPREAD) {
            _addIntoSortedListAndIncreaseAmount(account.shortPuts, false, longStrike, amount);
            _addIntoSortedListAndIncreaseAmount(account.longPuts, false, shortStrike, amount);
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function burnOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (TokenType optionType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = tokenId
            .parseTokenId();

        _verifyAndSetAccountInfo(account, productId, expiry);

        if (optionType == TokenType.CALL) {
            _decreaseAmountAndRemoveFromListIfEmpty(account.shortCalls, longStrike, amount);
        } else if (optionType == TokenType.PUT) {
            _decreaseAmountAndRemoveFromListIfEmpty(account.shortPuts, longStrike, amount);
        } else if (optionType == TokenType.CALL_SPREAD) {
            _decreaseAmountAndRemoveFromListIfEmpty(account.shortCalls, longStrike, amount);
            _decreaseAmountAndRemoveFromListIfEmpty(account.longCalls, shortStrike, amount);
        } else if (optionType == TokenType.PUT_SPREAD) {
            _decreaseAmountAndRemoveFromListIfEmpty(account.shortPuts, longStrike, amount);
            _decreaseAmountAndRemoveFromListIfEmpty(account.longPuts, shortStrike, amount);
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    ///@dev shortId and longId already have the same optionType, productId, expiry
    function merge(
        FullMarginAccountV2 storage, /*account*/
        uint256, /*shortId*/
        uint256, /*longId*/
        uint64 /*amount*/
    ) internal pure {
        revert("not implemented");
    }

    ///@dev split an accunt's spread position into short + 1 token
    function split(
        FullMarginAccountV2 storage, /*account*/
        uint256, /*spreadId*/
        uint64 /*amount*/
    ) internal pure {
        revert("not implemented");
    }

    function settleAtExpiry(FullMarginAccountV2 storage account, uint80 _payout) internal {}

    function getMinCollateral(
        FullMarginAccountV2 storage /*account*/
    ) internal pure returns (uint256) {
        return 0;
    }

    /**
     * @dev return masked token Id
     * @dev masked tokenId is usual token Id without the information of tokenType
     * @param _tokenId tokenId with TokenType in the first 24 bits
     * @return maskedId tokenId with first 24 bits being 0.
     */
    function _getMaskedTokenId(uint256 _tokenId) internal pure returns (uint256 maskedId) {
        maskedId = (_tokenId << 24) >> 24;
    }

    /**
     * @dev return series Id (underlying - strike - collateral - expiry)
     * @dev series Id is tokenId without information about TokenType & strikes
     * @param _tokenId tokenId with TokenType in the first 24 bits
     * @return seriesId tokenId with first 24 bits and last 128 bits being zero.
     */
    function _getSeriesInfo(uint256 _tokenId) internal pure returns (uint256 seriesId) {
        seriesId = (((_tokenId << 24) >> 24) >> 128) << 128;
    }

    function _verifyAndSetAccountInfo(
        FullMarginAccountV2 storage account,
        uint40 productId,
        uint64 expiry
    ) internal {
        (uint80 cacheCollatId, uint40 cachedProductId, uint64 cachedExpiry) = (
            account.collateralId,
            account.productId,
            account.expiry
        );
        // check if expiry is the same as stored
        if (cachedExpiry == 0) {
            account.expiry = expiry;
        } else {
            if (cachedExpiry != expiry) revert("wrong expiry");
        }

        // check if productId is the same as stored
        if (cachedProductId == 0) {
            account.productId = productId;
        } else {
            if (cachedProductId != productId) revert("wrong product");
        }

        // assign collateralId or check collateral id is the same
        (, , , , uint8 collateralId) = productId.parseProductId();

        // check if collateralId is same as stored (if previously only deposited collateral, id has to match)
        if (cacheCollatId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheCollatId != collateralId) revert FM_CollateraliMisMatch();
        }
    }

    /**
     * @param asc true if the list is sorted asc (low to high)
     */
    function _addIntoSortedListAndIncreaseAmount(
        LinkedList.ListWithAmount storage s,
        bool asc,
        uint64 strike,
        uint64 amount
    ) internal {
        // optimize: don't find exist and find first higher / lower in separate stpes
        bool exists = s.nodeExists(strike);
        if (!exists) {
            uint64 found;
            if (asc) {
                found = s.getFirstHigherThan(strike);
            } else {
                found = s.getFirstLowerThan(strike);
            }

            if (found > 0) {
                s.insertBefore(found, strike);
            } else {
                s.pushBack(strike);
            }
        }
        s.values[strike] += amount;
    }

    /**
     */
    function _decreaseAmountAndRemoveFromListIfEmpty(
        LinkedList.ListWithAmount storage s,
        uint64 strike,
        uint64 amount
    ) internal {
        uint64 existingAmount = s.values[strike];
        if (existingAmount < amount) revert("cannot burn");
        uint64 newAmount = existingAmount - amount;
        if (newAmount == 0) {
            // also remove value
            s.remove(strike);
        } else {
            s.values[strike] = newAmount;
        }
    }
}
