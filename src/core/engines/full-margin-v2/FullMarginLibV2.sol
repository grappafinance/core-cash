// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";
import "../../../libraries/ArrayUtil.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/utils/Console.sol";

/**
 * @title FullMarginLib
 * @dev   This library is in charge of updating the simple account memory struct and do validations
 */
library FullMarginLibV2 {
    using ArrayUtil for uint8[];
    using ArrayUtil for uint64[];
    using ArrayUtil for uint80[];
    using ArrayUtil for uint256[];
    using ProductIdUtil for uint40;
    using TokenIdUtil for uint256;

    /**
     * @dev return true if the account has no short,long positions nor collateral
     */
    function isEmpty(FullMarginAccountV2 storage account) internal view returns (bool) {
        return
            account.shortAmounts.sum() == 0 && account.longAmounts.sum() == 0 && account.collateralAmounts.sum() == 0;
    }

    ///@dev Increase the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function addCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        (bool found, uint256 index) = account.collaterals.indexOf(collateralId);

        if (!found) {
            account.collaterals.push(collateralId);
            account.collateralAmounts.push(amount);
            index = account.collaterals.length - 1;
        } else account.collateralAmounts[index] += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function removeCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) internal {
        (bool found, uint256 index) = account.collaterals.indexOf(collateralId);
        if (!found) revert FM_WrongCollateralId();

        uint80 newAmount = account.collateralAmounts[index] - amount;

        if (newAmount == 0) {
            account.collaterals = account.collaterals.remove(index);
            account.collateralAmounts = account.collateralAmounts.remove(index);
        } else account.collateralAmounts[index] = newAmount;
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function mintOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (TokenType optionType, uint40 productId, , , ) = tokenId.parseTokenId();

        // assign collateralId or check collateral id is the same
        (, , uint8 underlyingId, uint8 strikeId, uint8 collateralId) = productId.parseProductId();

        // engine doesnt support spreads
        if (optionType == TokenType.CALL_SPREAD || optionType == TokenType.PUT_SPREAD) revert FM_UnsupportedTokenType();

        // call can only collateralized by underlying
        if ((optionType == TokenType.CALL) && underlyingId != collateralId)
            revert FM_CannotMintOptionWithThisCollateral();

        // put can only be collateralized by strike
        if ((optionType == TokenType.PUT) && strikeId != collateralId) revert FM_CannotMintOptionWithThisCollateral();

        (bool found, uint256 index) = account.shorts.indexOf(tokenId);
        if (!found) {
            account.shorts.push(tokenId);
            account.shortAmounts.push(amount);
        } else account.shortAmounts[index] += amount;
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function burnOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) internal {
        (bool found, uint256 index) = account.shorts.indexOf(tokenId);

        if (!found) revert FM_InvalidToken();

        uint64 newShortAmount = account.shortAmounts[index] - amount;
        if (newShortAmount == 0) {
            account.shorts = account.shorts.remove(index);
            account.shortAmounts = account.shortAmounts.remove(index);
        } else account.shortAmounts[index] = newShortAmount;
    }

    function settleAtExpiry(
        FullMarginAccountV2 storage account,
        uint8[] memory collaterals,
        uint80[] memory payouts
    ) internal {
        // clear all debt
        delete account.shorts;
        delete account.shortAmounts;

        for (uint256 i = 0; i < collaterals.length; i++) {
            uint8 collateralId = collaterals[i];
            uint80 payout = payouts[i];

            (, uint256 index) = account.collaterals.indexOf(collateralId);

            account.collateralAmounts[index] = account.collateralAmounts[index] - payout;
        }
    }
}
