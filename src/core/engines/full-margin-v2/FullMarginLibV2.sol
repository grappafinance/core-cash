// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title FullMarginLib
 * @dev   This library is in charge of updating the simple account memory struct and do validations
 */
library FullMarginLibV2 {
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;

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
        (TokenType optionType, uint40 productId, uint64 expiry, , ) = tokenId.parseTokenId();
        // assign collateralId or check collateral id is the same
        (, , , , uint8 collateralId) = productId.parseProductId();

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

        // check if collateralId is same as stored (if previously only deposited collateral, id has to match)
        if (cacheCollatId == 0) {
            account.collateralId = collateralId;
        } else {
            if (cacheCollatId != collateralId) revert FM_CollateraliMisMatch();
        }

        // id used to store amounts.
        uint256 maskedId = _getMaskedTokenId(tokenId);

        if (optionType == TokenType.CALL) {
            // add to short call array
        } else if (optionType == TokenType.PUT) {
            // add to short put array
        } else if (optionType == TokenType.CALL_SPREAD) {
            // add to short call array & long call array
        } else if (optionType == TokenType.PUT_SPREAD) {
            // add to short put array & long put array
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function burnOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (TokenType optionType, , , , ) = tokenId.parseTokenId();

        if (optionType == TokenType.CALL) {
            // add to short call array
        } else if (optionType == TokenType.PUT) {
            // add to short put array
        } else if (optionType == TokenType.CALL_SPREAD) {
            // add to short call array & long call array
        } else if (optionType == TokenType.PUT_SPREAD) {
            // add to short put array & long put array
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    ///@dev shortId and longId already have the same optionType, productId, expiry
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    ///@param shortId existing short position to be converted into spread
    ///@param longId token to be "added" into the account. This is expected to have the same time of the exisiting short type.
    ///               e.g: if the account currenly have short call, we can added another "call token" into the account
    ///               and convert the short position to a spread.
    function merge(
        FullMarginAccountV2 storage account,
        uint256 shortId,
        uint256 longId,
        uint64 amount
    ) internal {
        revert("not implemented");
    }

    ///@dev split an accunt's spread position into short + 1 token
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    ///@param spreadId id of spread to be parsed
    function split(
        FullMarginAccountV2 storage account,
        uint256 spreadId,
        uint64 amount
    ) internal {
        revert("not implemented");
    }

    function settleAtExpiry(FullMarginAccountV2 storage account, uint80 _payout) internal {}

    function getMinCollateral(FullMarginAccountV2 storage account) internal view returns (uint256) {}

    /**
     * @dev return masked token Id
     * @dev masked tokenId is usual token Id without the information of tokenType
     * @param _tokenId tokenId with TokenType in the first 24 bits
     * @return maskedId tokenId with first 24 bits being 0.
     */
    function _getMaskedTokenId(uint256 _tokenId) internal view returns (uint256 maskedId) {
        maskedId = (_tokenId << 24) >> 24;
    }

    /**
     * @dev return series Id (underlying - strike - collateral - expiry)
     * @dev series Id is tokenId without information about TokenType & strikes
     * @param _tokenId tokenId with TokenType in the first 24 bits
     * @return seriesId tokenId with first 24 bits and last 128 bits being zero.
     */
    function _getSeriesInfo(uint256 _tokenId) internal view returns (uint256 seriesId) {
        seriesId = (((_tokenId << 24) >> 24) >> 128) << 128;
    }
}
