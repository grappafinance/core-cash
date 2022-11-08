// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";
import "../../../libraries/AccountUtil.sol";
import "../../../libraries/ArrayUtil.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title FullMarginLibV2
 * @dev   This library is in charge of updating the simple account memory struct and do validations
 */
library FullMarginLibV2 {
    using AccountUtil for Balance[];
    using AccountUtil for Position[];
    using AccountUtil for PositionOptim[];
    using ArrayUtil for uint256[];
    using ProductIdUtil for uint40;
    using TokenIdUtil for uint256;
    using TokenIdUtil for uint192;

    /**
     * @dev return true if the account has no short,long positions nor collateral
     */
    function isEmpty(FullMarginAccountV2 storage account) external view returns (bool) {
        return account.shorts.sum() == 0 && account.longs.sum() == 0 && account.collaterals.sum() == 0;
    }

    ///@dev Increase the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function addCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) public {
        if (amount == 0) return;

        (bool found, uint256 index) = account.collaterals.indexOf(collateralId);

        if (!found) {
            account.collaterals.push(Balance(collateralId, amount));
        } else account.collaterals[index].amount += amount;
    }

    ///@dev Reduce the collateral in the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function removeCollateral(
        FullMarginAccountV2 storage account,
        uint8 collateralId,
        uint80 amount
    ) public {
        Balance[] memory collaterals = account.collaterals;

        (bool found, uint256 index) = collaterals.indexOf(collateralId);

        if (!found) revert FM_WrongCollateralId();

        uint80 newAmount = collaterals[index].amount - amount;

        if (newAmount == 0) {
            account.collaterals.remove(index);
        } else account.collaterals[index].amount = newAmount;
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function mintOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) external {
        if (amount == 0) return;

        (TokenType optionType, uint40 productId, , , ) = tokenId.parseTokenId();

        // assign collateralId or check collateral id is the same
        (, , uint8 underlyingId, uint8 strikeId, uint8 collateralId) = productId.parseProductId();

        // engine only supports calls and puts
        if (optionType != TokenType.CALL && optionType != TokenType.PUT) revert FM_UnsupportedTokenType();

        // call can only collateralized by underlying
        if ((optionType == TokenType.CALL) && underlyingId != collateralId)
            revert FM_CannotMintOptionWithThisCollateral();

        // put can only be collateralized by strike
        if ((optionType == TokenType.PUT) && strikeId != collateralId) revert FM_CannotMintOptionWithThisCollateral();

        (bool found, uint256 index) = account.shorts.getPositions().indexOf(tokenId);
        if (!found) {
            account.shorts.pushPosition(Position(tokenId, amount));
        } else account.shorts[index].amount += amount;
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function burnOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) external {
        (bool found, PositionOptim memory position, uint256 index) = account.shorts.find(tokenId.compress());

        if (!found) revert FM_InvalidToken();

        uint64 newShortAmount = position.amount - amount;
        if (newShortAmount == 0) {
            account.shorts.removePositionAt(index);
        } else account.shorts[index].amount = newShortAmount;
    }

    ///@dev Increase the amount of long call or put (debt) of the account
    ///@param account FullMarginAccountV2 memory that will be updated
    function addOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) external {
        if (amount == 0) return;

        (bool found, uint256 index) = account.longs.indexOf(tokenId.compress());

        if (!found) {
            account.longs.pushPosition(Position(tokenId, amount));
        } else account.longs[index].amount += amount;
    }

    ///@dev Remove the amount of long call or put held by the account
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function removeOption(
        FullMarginAccountV2 storage account,
        uint256 tokenId,
        uint64 amount
    ) external {
        (bool found, PositionOptim memory position, uint256 index) = account.longs.find(tokenId.compress());

        if (!found) revert FM_InvalidToken();

        uint64 newLongAmount = position.amount - amount;
        if (newLongAmount == 0) {
            account.longs.removePositionAt(index);
        } else account.longs[index].amount = newLongAmount;
    }

    ///@dev Settles the accounts short calls and puts, reserving collateral for ITM options
    ///@param account FullMarginAccountV2 memory that will be updated in-place
    function settleAtExpiry(
        FullMarginAccountV2 storage account,
        // Balance[] memory payouts,
        IGrappa grappa
    ) external returns (Balance[] memory longPayouts, Balance[] memory shortPayouts) {
        // settling longs first as they can only increase collateral
        longPayouts = _settleLongs(grappa, account);
        // settling shorts last as they can only reduce collateral
        shortPayouts = _settleShorts(grappa, account);
    }

    function _settleLongs(IGrappa grappa, FullMarginAccountV2 storage account)
        public
        returns (Balance[] memory payouts)
    {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.longs.length) {
            uint256 tokenId = account.longs[i].tokenId.expand();

            if (tokenId.isExpired()) {
                tokenIds = tokenIds.append(tokenId);
                amounts = amounts.append(account.longs[i].amount);

                account.longs.removePositionAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            payouts = grappa.batchSettleOptions(address(this), tokenIds, amounts);

            for (i = 0; i < payouts.length; ) {
                addCollateral(account, payouts[i].collateralId, payouts[i].amount);

                unchecked {
                    ++i;
                }
            }
        }
    }

    function _settleShorts(IGrappa grappa, FullMarginAccountV2 storage account)
        public
        returns (Balance[] memory payouts)
    {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.shorts.length) {
            uint256 tokenId = account.shorts[i].tokenId.expand();

            if (tokenId.isExpired()) {
                tokenIds = tokenIds.append(tokenId);
                amounts = amounts.append(account.shorts[i].amount);

                account.shorts.removePositionAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            payouts = grappa.batchGetPayouts(tokenIds, amounts);

            for (i = 0; i < payouts.length; ) {
                removeCollateral(account, payouts[i].collateralId, payouts[i].amount);

                unchecked {
                    ++i;
                }
            }
        }
    }
}
