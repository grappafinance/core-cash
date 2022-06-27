// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "../config/enums.sol";

library TokenIdUtil {
    /**
     * @notice calculate ERC1155 token id for given option parameters
     *                  * ------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   tokenId = | tokenType (32 bits) | productId (32 bits) | expiry (64 bits) | longStrike (64 bits) | shortStrike (64 bits) |
     *                  * ------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
     * @param tokenType TokenType enum
     * @param productId if of the product
     * @param expiry timestamp of option expiry
     * @param longStrike strike price of the long option, with 6 decimals
     * @param shortStrike strike price of the short (upper bond for call and lower bond for put) if this is a spread. 6 decimals
     * @return tokenId token id
     */
    function formatTokenId(
        TokenType tokenType,
        uint32 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) internal pure returns (uint256 tokenId) {
        tokenId =
            (uint256(tokenType) << 224) +
            (uint256(productId) << 192) +
            (uint256(expiry) << 128) +
            (uint256(longStrike) << 64) +
            uint256(shortStrike);
    }

    /**
     * @notice derive option expiry and strike price from ERC1155 token id
     *                  * ------------------- | ------------------- | ----------------- | -------------------- | --------------------- *
     * @dev   tokenId = | tokenType (32 bits) | productId (32 bits) | expiry (64 bits)  | longStrike (64 bits) | shortStrike (64 bits) |
     *                  * ------------------- | ------------------- | ----------------- | -------------------- | --------------------- *
     * @param tokenId token id
     * @return tokenType TokenType enum
     * @return productId if of the product
     * @return expiry timestamp of option expiry
     * @return longStrike strike price of the long option, with 6 decimals
     * @return shortStrike strike price of the short (upper bond for call and lower bond for put) if this is a spread. 6 decimals
     */
    function parseTokenId(uint256 tokenId)
        internal
        pure
        returns (
            TokenType tokenType,
            uint32 productId,
            uint64 expiry,
            uint64 longStrike,
            uint64 shortStrike
        )
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tokenType := shr(224, tokenId)
            productId := shr(192, tokenId)
            expiry := shr(128, tokenId)
            longStrike := shr(64, tokenId)
            shortStrike := tokenId
        }
    }

    /**
     * @notice derive option type from ERC1155 token id
     *                  * ------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   tokenId = | tokenType (32 bits) | productId (32 bits) | expiry (64 bits) | longStrike (64 bits) | shortStrike (64 bits) |
     *                  * ------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
     * @param tokenId token id
     * @return tokenType TokenType enum
     */
    function parseTokenType(uint256 tokenId) internal pure returns (TokenType tokenType) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tokenType := shr(224, tokenId)
        }
    }
}
