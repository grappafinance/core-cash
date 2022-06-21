// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/console2.sol";
import {AssetDetail} from "src/config/types.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AssetRegistry is Ownable {
    error AlreadyRegistered();
    error NotAuthorized();

    /// @dev next id used to represent an address
    uint8 public nextId;

    /// @dev assetId => asset address
    mapping(uint8 => AssetDetail) public assets;

    /// @dev address => assetId
    mapping(address => uint8) public ids;

    /// @dev address => authorized to mint
    // mapping(address => bool) public isMinter;

    /// Events

    event MinterUpdated(address minter, bool isMinter);
    event AssetRegistered(address asset, uint8 id);

    // solhint-disable-next-line no-empty-blocks
    constructor() Ownable() {}

    ///@dev register an asset to be used as strike/underlying
    ///@param _asset address to add
    function registerAsset(address _asset) external onlyOwner returns (uint8 id) {
        if (ids[_asset] != 0) revert AlreadyRegistered();

        uint8 decimals = IERC20Metadata(_asset).decimals();

        id = ++nextId;
        assets[id] = AssetDetail({addr: uint160(_asset), decimals: decimals});
        ids[_asset] = id;

        emit AssetRegistered(_asset, id);
    }
}
