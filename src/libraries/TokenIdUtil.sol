// SPDX-License-Identifier: MIT
// solhint-disable max-line-length

pragma solidity ^0.8.0;

import "../config/enums.sol";
import "../config/errors.sol";

/**
 * Token ID =
 *
 *  * ------------------------ | ----------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
 *  | tokenType (16 bits) | settlementType (8 bits) | productId (40 bits) | expiry (64 bits) | strike (64 bits)     | reserved (64 bits)    |
 *  * ------------------------ | ----------------------- | ------------------- | ---------------- | -------------------- | --------------------- *
 */
library TokenIdUtil {
    /**
     * @notice calculate ERC1155 token id for given option parameters. See table above for tokenId
     * @param tokenType TokenType enum
     * @param settlementType SettlementType enum
     * @param productId id of the product
     * @param expiry timestamp of option expiry
     * @param strike strike price of the option, with 6 decimals
     * @param reserved allocated space for additional data
     * @return tokenId token id
     */
    function getTokenId(
        TokenType tokenType,
        SettlementType settlementType,
        uint40 productId,
        uint64 expiry,
        uint64 strike,
        uint64 reserved
    ) internal pure returns (uint256 tokenId) {
        unchecked {
            tokenId = (uint256(tokenType) << 240) + (uint256(settlementType) << 232) + (uint256(productId) << 192)
                + (uint256(expiry) << 128) + (uint256(strike) << 64) + uint256(reserved);
        }
    }

    /**
     * @notice derive option, settlement, product, expiry and strike price from ERC1155 token id
     * @dev    See table above for tokenId composition
     * @param tokenId token id
     * @return tokenType TokenType enum
     * @return settlementType SettlementType enum
     * @return productId 40 bits product id
     * @return expiry timestamp of option expiry
     * @return strike strike price of the option, with 6 decimals
     * @return reserved allocated space for additional data
     */
    function parseTokenId(uint256 tokenId)
        internal
        pure
        returns (
            TokenType tokenType,
            SettlementType settlementType,
            uint40 productId,
            uint64 expiry,
            uint64 strike,
            uint64 reserved
        )
    {
        uint8 _settlementType;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            tokenType := shr(240, tokenId)
            _settlementType := shr(232, tokenId)
            productId := shr(192, tokenId)
            expiry := shr(128, tokenId)
            strike := shr(64, tokenId)
            reserved := tokenId
        }

        settlementType = SettlementType(_settlementType);
    }

    /**
     * @notice parse collateral id from tokenId
     * @dev more efficient than parsing tokenId and than parse productId
     * @param tokenId token id
     * @return collateralId
     */
    function parseCollateralId(uint256 tokenId) internal pure returns (uint8 collateralId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // collateralId is the last bits of productId
            collateralId := shr(192, tokenId)
        }
    }

    /**
     * @notice parse engine id from tokenId
     * @dev more efficient than parsing tokenId and than parse productId
     * @param tokenId token id
     * @return engineId
     */
    function parseEngineId(uint256 tokenId) internal pure returns (uint8 engineId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // collateralId is the last bits of productId
            engineId := shr(216, tokenId) // 192 to get product id, another 24 to get engineId
        }
    }

    /**
     * @notice derive option type from ERC1155 token id
     * @param tokenId token id
     * @return tokenType TokenType enum
     */
    function parseTokenType(uint256 tokenId) internal pure returns (TokenType tokenType) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tokenType := shr(240, tokenId)
        }
    }

    /**
     * @notice derive option settlement type from ERC1155 token id
     * @param tokenId token id
     * @return settlementType SettlementType enum
     */
    function parseSettlementType(uint256 tokenId) internal pure returns (SettlementType) {
        uint8 settlementType;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            settlementType := shr(232, tokenId)
        }

        return SettlementType(settlementType);
    }

    /**
     * @notice derive if option is cash settled from ERC1155 token id
     * @param tokenId token id
     * @return cash bool
     */
    function isCash(uint256 tokenId) internal pure returns (bool) {
        return parseSettlementType(tokenId) == SettlementType.CASH;
    }

    /**
     * @notice derive if option is cash settled from ERC1155 token id
     * @param tokenId token id
     * @return cash bool
     */
    function isPhysical(uint256 tokenId) internal pure returns (bool) {
        return parseSettlementType(tokenId) == SettlementType.PHYSICAL;
    }

    /**
     * @notice derive if option is expired from ERC1155 token id
     * @param tokenId token id
     * @return expired bool
     */
    function isExpired(uint256 tokenId) internal view returns (bool expired) {
        uint64 expiry;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            expiry := shr(128, tokenId)
        }

        expired = block.timestamp >= expiry;
    }

    /**
     * @notice convert an spread tokenId back to put or call.
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   oldId =   | spread type (16 b)  | settlementType  (8 bits) | productId (40 bits) | expiry (64 bits) | longStrike (64 bits) | shortStrike (64 bits) |
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   newId =   | call or put type    | settlementType  (8 bits) | productId (40 bits) | expiry (64 bits) | longStrike (64 bits) | 0           (64 bits) |
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     *        this function will: override tokenType, remove shortStrike.
     * @dev   this should only be used with DebitSpread Contract
     * @param _tokenId token id to change
     */
    function convertToVanillaId(uint256 _tokenId) internal pure returns (uint256 newId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            newId := shr(64, _tokenId) // step 1: >> 64 to wipe out shortStrike
            newId := shl(64, newId) // step 2: << 64 go back

            newId := sub(newId, shl(240, 1)) // step 3: new tokenType = spread type - 1
        }
    }

    /**
     * @notice convert an spread tokenId back to put or call.
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   oldId =   | call or put type    | settlementType  (8 bits) | productId (40 bits) | expiry (64 bits) | longStrike (64 bits) | 0           (64 bits) |
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     * @dev   newId =   | spread type         | settlementType  (8 bits) | productId (40 bits) | expiry (64 bits) | longStrike (64 bits) | shortStrike (64 bits) |
     *                  * ------------------- | ------------------------ | ------------------- | ---------------- | -------------------- | --------------------- *
     *
     *        this function convert put or call type to spread type, add shortStrike.
     * @dev   this should only be used with DebitSpread Contract
     * @param _tokenId token id to change
     * @param _shortStrike strike to add
     */
    function convertToSpreadId(uint256 _tokenId, uint256 _shortStrike) internal pure returns (uint256 newId) {
        // solhint-disable-next-line no-inline-assembly
        unchecked {
            newId = _tokenId + _shortStrike;
            return newId + (1 << 240); // new type (spread type) = old type + 1
        }
    }
}
