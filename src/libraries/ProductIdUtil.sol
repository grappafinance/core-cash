// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ProductIdUtil {
    /**
     * @dev parse product id into composing asset ids
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     * productId (32 bits) =  | reserved (8 bits) | underlying ID (8 bits) | strike ID (8 bits) | collateral ID (8 bits) |
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     * @param _productId product id
     */
    function parseProductId(uint32 _productId)
        internal
        pure
        returns (
            uint8 engineId,
            uint8 underlyingId,
            uint8 strikeId,
            uint8 collateralId
        )
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            engineId := shr(24, _productId)
            underlyingId := shr(16, _productId)
            strikeId := shr(8, _productId)
        }
        collateralId = uint8(_productId);
    }

    /**
     * @dev parse collateral id from product Id.
     *      since collateral id is uint8 of the last 8 bits of productId, we can just cast to uint8
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     * productId (32 bits) =  | engineId (8 bits) | underlying ID (8 bits) | strike ID (8 bits) | collateral ID (8 bits) |
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     */
    function getCollateralId(uint32 _productId) internal pure returns (uint8) {
        return uint8(_productId);
    }

    /**
     * @notice    get product id from underlying, strike and collateral address
     * @dev       function will still return even if some of the assets are not registered
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     * productId (32 bits) =  | engineId (8 bits) | underlying ID (8 bits) | strike ID (8 bits) | collateral ID (8 bits) |
     *                        * ----------------- | ---------------------- | ------------------ | ---------------------- *
     * @param underlyingId  underlying id
     * @param strikeId      strike id
     * @param collateralId  collateral id
     */
    function getProductId(
        uint8 engineId,
        uint8 underlyingId,
        uint8 strikeId,
        uint8 collateralId
    ) internal pure returns (uint32 id) {
        unchecked {
            id =
                (uint32(engineId) << 24) +
                (uint32(underlyingId) << 16) +
                (uint32(strikeId) << 8) +
                (uint32(collateralId));
        }
    }
}
