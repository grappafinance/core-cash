// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../config/enums.sol";
import "../config/types.sol";

/**
 * @title libraries to encode action arguments
 */
library ActionUtil {
    /**
     * @param collateralId id of collateral
     * @param amount amount of collateral to deposit
     * @param from address to pull asset from
     */
    function createAddCollateralAction(
        uint8 collateralId,
        uint256 amount,
        address from
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.AddCollateral, data: abi.encode(from, uint80(amount), collateralId)});
    }

    /**
     * @param collateralId id of collateral
     * @param amount amount of collateral to remove
     * @param recipient address to receive removed collateral
     */
    function createRemoveCollateralAction(
        uint8 collateralId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({
            action: ActionType.RemoveCollateral,
            data: abi.encode(uint80(amount), recipient, collateralId)
        });
    }

    /**
     * @param collateralId id of collateral
     * @param amount amount of collateral to remove
     * @param recipient address to receive removed collateral
     */
    function createTransferCollateralAction(
        uint8 collateralId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({
            action: ActionType.TransferCollateral,
            data: abi.encode(uint80(amount), recipient, collateralId)
        });
    }

    /**
     * @param tokenId option token id to mint
     * @param amount amount of token to mint (6 decimals)
     * @param recipient address to receive minted option
     */
    function createMintAction(
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    /**
     * @param tokenId option token id to mint
     * @param amount amount of token to mint (6 decimals)
     * @param recipient account to receive minted option
     */
    function createMintIntoAccountAction(
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({
            action: ActionType.MintShortIntoAccount,
            data: abi.encode(tokenId, recipient, uint64(amount))
        });
    }

    /**
     * @param tokenId option token id to mint
     * @param amount amount of token to mint (6 decimals)
     * @param recipient account to receive minted option
     */
    function createTranferLongAction(
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.TransferLong, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    /**
     * @param tokenId option token id to mint
     * @param amount amount of token to mint (6 decimals)
     * @param recipient account to receive minted option
     */
    function createTranferShortAction(
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.TransferShort, data: abi.encode(tokenId, recipient, uint64(amount))});
    }

    /**
     * @param tokenId option token id to burn
     * @param amount amount of token to burn (6 decimals)
     * @param from address to burn option token from
     */
    function createBurnAction(
        uint256 tokenId,
        uint256 amount,
        address from
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.BurnShort, data: abi.encode(tokenId, from, uint64(amount))});
    }

    /**
     * @param tokenId option token id of the incoming option token.
     * @param shortId the currently shorted "option token id" to merge the option token into
     * @param amount amount to merge
     * @param from which address to burn the incoming option from.
     */
    function createMergeAction(
        uint256 tokenId,
        uint256 shortId,
        uint256 amount,
        address from
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.MergeOptionToken, data: abi.encode(tokenId, shortId, from, amount)});
    }

    /**
     * @param spreadId current shorted "spread option id"
     * @param amount amount to split
     * @param recipient address to receive the "splited" long option token.
     */
    function createSplitAction(
        uint256 spreadId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({
            action: ActionType.SplitOptionToken,
            data: abi.encode(spreadId, uint64(amount), recipient)
        });
    }

    /**
     * @param tokenId option token to be added to the account
     * @param amount amount to add
     * @param from address to pull the token from
     */
    function createAddLongAction(
        uint256 tokenId,
        uint256 amount,
        address from
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.AddLong, data: abi.encode(tokenId, uint64(amount), from)});
    }

    /**
     * @param tokenId option token to be removed from an account
     * @param amount amount to remove
     * @param recipient address to receive the removed option
     */
    function createRemoveLongAction(
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.RemoveLong, data: abi.encode(tokenId, uint64(amount), recipient)});
    }

    /**
     * @dev create action to settle an account
     */
    function createSettleAction() internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.SettleAccount, data: abi.encode(0)});
    }

    function append(ActionArgs[] memory x, ActionArgs memory v) internal pure returns (ActionArgs[] memory y) {
        y = new ActionArgs[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                i++;
            }
        }
        y[i] = v;
    }
}
