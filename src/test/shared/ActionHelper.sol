// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console2.sol";

import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountEnums.sol";
import "src/constants/TokenEnums.sol";

import "src/libraries/OptionTokenUtils.sol";

contract ActionHelper {
    function getTokenId(
        TokenType tokenType,
        uint32 productId,
        uint256 expiry,
        uint256 longStrike,
        uint256 shortStrike
    ) internal pure returns (uint256 tokenId) {
        tokenId = OptionTokenUtils.formatTokenId(
            tokenType,
            productId,
            uint64(expiry),
            uint64(longStrike),
            uint64(shortStrike)
        );
    }

    function createAddCollateralAction(address collateral, address from, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        action = ActionArgs({action: ActionType.AddCollateral, data: abi.encode(collateral, from, amount)});
    }

    function createRemoveCollateralAction(uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        action = ActionArgs({action: ActionType.RemoveCollateral, data: abi.encode(amount, recipient)});
    }

    function createMintAction(
        uint256 tokenId,
        address recipient,
        uint256 amount
    ) internal pure returns (ActionArgs memory action) {
        action = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, recipient, amount)});
    }
}
