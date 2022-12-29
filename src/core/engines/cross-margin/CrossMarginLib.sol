// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import "../../../libraries/TokenIdUtil.sol";
import "../../../libraries/ProductIdUtil.sol";
import "../../../libraries/BalanceUtil.sol";
import "../../../libraries/ArrayUtil.sol";

import "../../../config/types.sol";
import "../../../config/constants.sol";

// Cross Margin libraries and configs
import "./AccountUtil.sol";
import "./types.sol";
import "./errors.sol";

/**
 * @title CrossMarginLib
 * @dev   This library is in charge of updating the simple account struct and do validations
 */
library CrossMarginLib {
    using BalanceUtil for Balance[];
    using AccountUtil for Position[];
    using ArrayUtil for uint256[];
    using ProductIdUtil for uint40;
    using TokenIdUtil for uint256;

    /**
     * @dev return true if the account has no short,long positions nor collateral
     */
    function isEmpty(CrossMarginAccount storage account) external view returns (bool) {
        return account.shorts.sum() == 0 && account.longs.sum() == 0 && account.collaterals.sum() == 0;
    }

    ///@dev Increase the collateral in the account
    ///@param account CrossMarginAccount storage that will be updated
    function addCollateral(CrossMarginAccount storage account, uint8 collateralId, uint80 amount) public {
        if (amount == 0) return;

        (bool found, uint256 index) = account.collaterals.indexOf(collateralId);

        if (!found) {
            account.collaterals.push(Balance(collateralId, amount));
        } else {
            account.collaterals[index].amount += amount;
        }
    }

    ///@dev Reduce the collateral in the account
    ///@param account CrossMarginAccount storage that will be updated
    function removeCollateral(CrossMarginAccount storage account, uint8 collateralId, uint80 amount) public {
        Balance[] memory collaterals = account.collaterals;

        (bool found, uint256 index) = collaterals.indexOf(collateralId);

        if (!found) revert CM_WrongCollateralId();

        uint80 newAmount = collaterals[index].amount - amount;

        if (newAmount == 0) {
            account.collaterals.remove(index);
        } else {
            account.collaterals[index].amount = newAmount;
        }
    }

    ///@dev Increase the amount of short call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated
    function mintOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        if (amount == 0) return;

        (DerivativeType derivativeType,, uint40 productId,,,) = tokenId.parseTokenId();

        // assign collateralId or check collateral id is the same
        (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = productId.parseProductId();

        // engine only supports calls and puts
        if (derivativeType != DerivativeType.CALL && derivativeType != DerivativeType.PUT) revert CM_UnsupportedDerivativeType();

        // call can only collateralized by underlying
        if ((derivativeType == DerivativeType.CALL) && underlyingId != collateralId) {
            revert CM_CannotMintOptionWithThisCollateral();
        }

        // put can only be collateralized by strike
        if ((derivativeType == DerivativeType.PUT) && strikeId != collateralId) revert CM_CannotMintOptionWithThisCollateral();

        (bool found, uint256 index) = account.shorts.indexOf(tokenId);
        if (!found) {
            account.shorts.push(Position(tokenId, amount));
        } else {
            account.shorts[index].amount += amount;
        }
    }

    ///@dev Remove the amount of short call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated in-place
    function burnOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        (bool found, Position memory position, uint256 index) = account.shorts.find(tokenId);

        if (!found) revert CM_InvalidToken();

        uint64 newShortAmount = position.amount - amount;
        if (newShortAmount == 0) {
            account.shorts.removeAt(index);
        } else {
            account.shorts[index].amount = newShortAmount;
        }
    }

    ///@dev Increase the amount of long call or put (debt) of the account
    ///@param account CrossMarginAccount storage that will be updated
    function addOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        if (amount == 0) return;

        (bool found, uint256 index) = account.longs.indexOf(tokenId);

        if (!found) {
            account.longs.push(Position(tokenId, amount));
        } else {
            account.longs[index].amount += amount;
        }
    }

    ///@dev Remove the amount of long call or put held by the account
    ///@param account CrossMarginAccount storage that will be updated in-place
    function removeOption(CrossMarginAccount storage account, uint256 tokenId, uint64 amount) external {
        (bool found, Position memory position, uint256 index) = account.longs.find(tokenId);

        if (!found) revert CM_InvalidToken();

        uint64 newLongAmount = position.amount - amount;
        if (newLongAmount == 0) {
            account.longs.removeAt(index);
        } else {
            account.longs[index].amount = newLongAmount;
        }
    }

    ///@dev Settles the accounts longs and shorts
    ///@param account CrossMarginAccount storage that will be updated in-place
    function settleAtExpiry(CrossMarginAccount storage account, IGrappa grappa, uint256 physicalSettlementWindow)
        external
        returns (Balance[] memory longDebts, Balance[] memory longPayouts, Balance[] memory shortPayouts)
    {
        // settling longs first as they can only increase collateral
        (longDebts, longPayouts) = _settleLongs(grappa, account, physicalSettlementWindow);
        // settling shorts last as they can only reduce collateral
        shortPayouts = _settleShorts(grappa, account, physicalSettlementWindow);
    }

    ///@dev Settles the accounts longs, adding collateral to balances
    ///@param grappa interface to settle long options in a batch call
    ///@param account CrossMarginAccount memory that will be updated in-place
    function _settleLongs(IGrappa grappa, CrossMarginAccount storage account, uint256 physicalSettlementWindow)
        public
        returns (Balance[] memory debts, Balance[] memory payouts)
    {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.longs.length) {
            uint256 tokenId = account.longs[i].tokenId;

            bool expired = tokenId.isExpired();
            bool isPhysical = tokenId.isPhysical();
            bool canSettle = true;

            // can only settle long physical options before the end of the settlement window
            if (expired && isPhysical) {
                (,,, uint64 expiry,,) = tokenId.parseTokenId();

                if (block.timestamp > expiry + physicalSettlementWindow) {
                    canSettle = false;
                }
            }

            if (expired) {
                // if physical options still exists but is outside settlement window
                // we dont try to settle, we just remove it
                if (!isPhysical || (isPhysical && canSettle)) {
                    tokenIds = tokenIds.append(tokenId);
                    amounts = amounts.append(account.longs[i].amount);
                }

                account.longs.removeAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            // debts is what was sent to the issuer of a physical option
            // payouts is the collateral that the option was settled for
            // debts[i] > 0 for physical settled options
            // debts[i] = 0 for cash settled options
            // payouts[i] = 0 for OTM cash settled,
            // payouts[i] > 0 for physical settled options
            (debts, payouts) = grappa.batchSettle(address(this), tokenIds, amounts, false);

            for (i = 0; i < debts.length;) {
                if (debts[i].amount != 0) {
                    // remove the collateral in the account storage.
                    removeCollateral(account, debts[i].collateralId, debts[i].amount);
                }

                unchecked {
                    ++i;
                }
            }

            for (i = 0; i < payouts.length;) {
                if (payouts[i].amount != 0) {
                    // add the collateral in the account storage.
                    addCollateral(account, payouts[i].collateralId, payouts[i].amount);
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    ///@dev Settles the accounts shorts, reserving collateral for ITM options
    ///@param grappa interface to get short option payouts in a batch call
    ///@param account CrossMarginAccount memory that will be updated in-place
    function _settleShorts(IGrappa grappa, CrossMarginAccount storage account, uint256 physicalSettlementWindow)
        public
        returns (Balance[] memory payouts)
    {
        uint256 i;
        uint256[] memory tokenIds;
        uint256[] memory amounts;

        while (i < account.shorts.length) {
            uint256 tokenId = account.shorts[i].tokenId;

            bool expired = tokenId.isExpired();
            bool isPhysical = tokenId.isPhysical();
            bool canSettle = true;

            // can only settle short physical options after the settlement window
            if (expired && isPhysical) {
                (,,, uint64 expiry,,) = tokenId.parseTokenId();

                if (block.timestamp < expiry + physicalSettlementWindow) {
                    canSettle = false;
                }
            }

            if (expired && canSettle) {
                // if physical options still exists it means it wasnt exercised
                // so we dont try to settle, we just remove it
                if (!isPhysical) {
                    tokenIds = tokenIds.append(tokenId);
                    amounts = amounts.append(account.shorts[i].amount);
                }

                account.shorts.removeAt(i);
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (tokenIds.length > 0) {
            // only concerned with payouts of cash settled options
            // physical options will payout in full or not at all
            (, payouts) = grappa.batchSettle(address(this), tokenIds, amounts, true);

            for (i = 0; i < payouts.length;) {
                if (payouts[i].amount != 0) {
                    // remove the collateral in the account storage.
                    removeCollateral(account, payouts[i].collateralId, payouts[i].amount);
                }

                unchecked {
                    ++i;
                }
            }
        }
    }
}
