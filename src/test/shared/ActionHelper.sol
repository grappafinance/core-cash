// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../config/enums.sol";
import "../../config/types.sol";

import "../../libraries/TokenIdUtil.sol";
import "../../libraries/ActionUtil.sol";

abstract contract ActionHelper {
    function getTokenId(
        SettlementType settlementType,
        TokenType tokenType,
        uint40 productId,
        uint256 expiry,
        uint256 strike,
        uint256 reserved
    ) internal pure returns (uint256 tokenId) {
        tokenId = TokenIdUtil.getTokenId(settlementType, tokenType, productId, uint64(expiry), uint64(strike), uint64(reserved));
    }

    function parseTokenId(uint256 tokenId)
        internal
        pure
        returns (
            SettlementType settlementType,
            TokenType tokenType,
            uint40 productId,
            uint64 expiry,
            uint64 strike,
            uint64 reserved
        )
    {
        return TokenIdUtil.parseTokenId(tokenId);
    }

    function createAddCollateralAction(uint8 collateralId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createAddCollateralAction(collateralId, amount, from);
    }

    function createRemoveCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createRemoveCollateralAction(collateralId, amount, recipient);
    }

    function createTransferCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createTransferCollateralAction(collateralId, amount, recipient);
    }

    function createMintAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createMintAction(tokenId, amount, recipient);
    }

    function createMintIntoAccountAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createMintIntoAccountAction(tokenId, amount, recipient);
    }

    function createBurnAction(uint256 tokenId, address from, uint256 amount) internal pure returns (ActionArgs memory action) {
        return ActionUtil.createBurnAction(tokenId, amount, from);
    }

    function createTransferLongAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createTransferLongAction(tokenId, amount, recipient);
    }

    function createTransferShortAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createTransferShortAction(tokenId, amount, recipient);
    }

    function createMergeAction(uint256 tokenId, uint256 shortId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createMergeAction(tokenId, shortId, amount, from);
    }

    function createSplitAction(uint256 spreadId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createSplitAction(spreadId, amount, recipient);
    }

    function createAddLongAction(uint256 tokenId, uint256 amount, address from)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createAddLongAction(tokenId, amount, from);
    }

    function createRemoveLongAction(uint256 tokenId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return ActionUtil.createRemoveLongAction(tokenId, amount, recipient);
    }

    function createSettleAction() internal pure returns (ActionArgs memory action) {
        return ActionUtil.createSettleAction();
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testForgeCoverageIgnoreThis() public {}
}
