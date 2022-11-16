// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Describes Option NFT
interface IOptionTokenDescriptor {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
