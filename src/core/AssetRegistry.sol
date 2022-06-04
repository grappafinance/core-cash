// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/console2.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AssetRegistry is Ownable {
    error AlreadyRegistered();
    error NotAuthorized();

    /// @dev next id used to represent an address
    uint8 public nextId;

    /// @dev assetId => asset address
    mapping(uint8 => address) public assets;

    /// @dev address => assetId
    mapping(address => uint8) public ids;

    /// @dev address => authorized to mint
    mapping(address => bool) public isMinter;

    /// Events

    event MinterUpdated(address minter, bool isMinter);
    event AssetRegistered(address asset, uint8 id);

    // solhint-disable-next-line no-empty-blocks
    constructor() Ownable() {}

    ///@dev             set who can mint and burn token
    ///@param _minter   minter address
    ///@param _isMinter grant or revoke access
    function setIsMinter(address _minter, bool _isMinter) external onlyOwner {
        isMinter[_minter] = _isMinter;

        emit MinterUpdated(_minter, _isMinter);
    }

    ///@dev register an asset to be used as strike/underlying
    ///@param _asset address to add
    function registerAsset(address _asset) external onlyOwner returns (uint8 id) {
        if (ids[_asset] != 0) revert AlreadyRegistered();
        id = ++nextId;
        assets[id] = _asset;
        ids[_asset] = id;

        emit AssetRegistered(_asset, id);
    }
}
