// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {AssetDetail} from "src/config/types.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AssetRegistry is Ownable {
    error AlreadyRegistered();

    /// @dev next id used to represent an address
    uint8 public nextId;

    /// @dev assetId => asset address
    mapping(uint8 => AssetDetail) public assets;

    /// @dev address => assetId
    mapping(address => uint8) public ids;

    /// Events

    event MinterUpdated(address minter, bool isMinter);
    event AssetRegistered(address asset, uint8 id);

    // solhint-disable-next-line no-empty-blocks
    constructor() Ownable() {}

    /**
     * @dev parse product id into composing asset addresses
     *                        * -------------- | ---------------------- | ------------------ | ---------------------- *
     * productId (32 bits) =  | empty (8 bits) | underlying ID (8 bits) | strike ID (8 bits) | collateral ID (8 bits) |
     *                        * -------------- | ---------------------- | ------------------ | ---------------------- *
     * @param _productId product id
     */
    function parseProductId(uint32 _productId)
        public
        view
        returns (
            address underlying,
            address strike,
            address collateral,
            uint8 collateralDecimals
        )
    {
        (uint8 underlyingId, uint8 strikeId) = (0, 0);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            underlyingId := shr(16, _productId)
            strikeId := shr(8, _productId)
        }
        uint8 collateralId = uint8(_productId);
        AssetDetail memory collateralDetail = assets[collateralId];
        return (
            address(assets[underlyingId].addr),
            address(assets[strikeId].addr),
            address(collateralDetail.addr),
            collateralDetail.decimals
        );
    }

    /**
     * @notice    get product id from underlying, strike and collateral address
     * @dev       function will still return even if some of the assets are not registered
     *                        * -------------- | ---------------------- | ------------------ | ---------------------- *
     * productId (32 bits) =  | empty (8 bits) | underlying ID (8 bits) | strike ID (8 bits) | collateral ID (8 bits) |
     *                        * -------------- | ---------------------- | ------------------ | ---------------------- *
     * @param underlying  underlying address
     * @param strike      strike address
     * @param collateral  collateral address
     */
    function getProductId(
        address underlying,
        address strike,
        address collateral
    ) public view returns (uint32 id) {
        id = (uint32(ids[underlying]) << 16) + (uint32(ids[strike]) << 8) + (uint32(ids[collateral]));
    }

    /**
     * @dev register an asset to be used as strike/underlying
     * @param _asset address to add
     **/
    function registerAsset(address _asset) external onlyOwner returns (uint8 id) {
        if (ids[_asset] != 0) revert AlreadyRegistered();

        uint8 decimals = IERC20Metadata(_asset).decimals();

        id = ++nextId;
        assets[id] = AssetDetail({addr: uint160(_asset), decimals: decimals});
        ids[_asset] = id;

        emit AssetRegistered(_asset, id);
    }
}
