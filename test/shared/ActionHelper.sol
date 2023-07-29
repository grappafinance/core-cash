// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/config/enums.sol";
import "../../src/config/types.sol";

import "../../src/libraries/TokenIdUtil.sol";
import "../../src/libraries/CashActionUtil.sol";

abstract contract ActionHelper {
    function getTokenId(TokenType tokenType, uint40 productId, uint256 expiry, uint256 longStrike, uint256 shortStrike)
        internal
        pure
        returns (uint256 tokenId)
    {
        tokenId = TokenIdUtil.getTokenId(tokenType, productId, uint64(expiry), uint64(longStrike), uint64(shortStrike));
    }

    function parseTokenId(uint256 tokenId)
        internal
        pure
        returns (TokenType tokenType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike)
    {
        return TokenIdUtil.parseTokenId(tokenId);
    }

    function createAddCollateralAction(uint8 collateralId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createAddCollateralAction(collateralId, amount, from);
    }

    function createRemoveCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createRemoveCollateralAction(collateralId, amount, recipient);
    }

    function createTransferCollateralAction(uint256 amount, uint8 collateralId, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createTransferCollateralAction(collateralId, amount, recipient);
    }

    function createMintAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createMintAction(tokenId, amount, recipient);
    }

    function createMintIntoAccountAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createMintIntoAccountAction(tokenId, amount, recipient);
    }

    function createBurnAction(uint256 tokenId, address from, uint256 amount) internal pure returns (ActionArgs memory action) {
        return CashActionUtil.createBurnAction(tokenId, amount, from);
    }

    function createTransferLongAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createTransferLongAction(tokenId, amount, recipient);
    }

    function createTransferShortAction(uint256 tokenId, address recipient, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createTransferShortAction(tokenId, amount, recipient);
    }

    function createMergeAction(uint256 tokenId, uint256 shortId, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createMergeAction(tokenId, shortId, amount, from);
    }

    function createSplitAction(uint256 spreadId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createSplitAction(spreadId, amount, recipient);
    }

    function createAddLongAction(uint256 tokenId, uint256 amount, address from)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createAddLongAction(tokenId, amount, from);
    }

    function createRemoveLongAction(uint256 tokenId, uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        return CashActionUtil.createRemoveLongAction(tokenId, amount, recipient);
    }

    function createSettleAction() internal pure returns (ActionArgs memory action) {
        return CashActionUtil.createSettleAction();
    }
}
