// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import "forge-std/console2.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AssetRegistry is Ownable {
    error AlreadyRegistered();

    uint8 public nextId;

    /// @dev assetId => asset address
    mapping(uint8 => address) public assets;

    /// @dev address => assetId
    mapping(address => uint8) public ids;

    constructor() Ownable() {}

    function registerAsset(address _asset) external onlyOwner {
        if (ids[_asset] != 0) revert AlreadyRegistered();
        uint8 id = ++nextId;
        assets[id] = _asset;
        ids[_asset] = id;
    }

    // todo: move to somewhere appropriate
    function parseProductId(uint32 _productId)
        internal
        view
        returns (
            address underlying,
            address strike,
            address collateral
        )
    {
        (uint8 underlyingId, uint8 strikeId, uint8 collateralId) = (0, 0, 0);
        assembly {
            underlyingId := shr(24, _productId)
            strikeId := shr(16, _productId)
            collateralId := shr(8, _productId)
            // the last 8 bits are not used
        }
        return (assets[underlyingId], assets[strikeId], assets[collateralId]);
    }
}
