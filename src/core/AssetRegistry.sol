// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import "forge-std/console2.sol";

import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AssetRegistry is Ownable {
    error AlreadyRegistered();
    error NotAuthorized();

    uint8 public nextId;

    /// @dev assetId => asset address
    mapping(uint8 => address) public assets;

    /// @dev address => assetId
    mapping(address => uint8) public ids;

    mapping(address => bool) public isMinter;

    /// Events

    event MinterUpdated(address minter, bool isMinter);
    event AssetRegistered(address asset, uint8 id);

    constructor() Ownable() {}

    ///@dev     set who can mint and burn tokens
    ///         this function is only callable by owner
    ///@param _minter minter address
    ///@param _isMinter grant or revoke access
    function setIsMinter(address _minter, bool _isMinter) external onlyOwner {
        isMinter[_minter] = _isMinter;

        emit MinterUpdated(_minter, _isMinter);
    }

    function registerAsset(address _asset) external onlyOwner returns (uint8 id) {
        if (ids[_asset] != 0) revert AlreadyRegistered();
        id = ++nextId;
        assets[id] = _asset;
        ids[_asset] = id;

        emit AssetRegistered(_asset, id);
    }

    function _checkCanMint() internal view {
        if (!isMinter[msg.sender]) revert NotAuthorized();
    }
}
