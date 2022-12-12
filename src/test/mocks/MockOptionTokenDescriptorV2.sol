// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/utils/Strings.sol";

/**
 * @title   MockOptionTokenDesciptor
 * @notice  Mock contract to test upgradability for token desciptor
 */
contract MockTokenDescriptorV2 is UUPSUpgradeable {
    /**
     * @notice return tokenURL
     * @dev for v1, we just simply put a static url
     */
    function tokenURI(uint256 id) external pure returns (string memory) {
        return string(abi.encodePacked("https://grappa.finance/token/v2/", Strings.toString(id)));
    }

    /**
     * @dev Upgradable by the owner.
     *
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal pure override {
        revert("not upgradable anymore");
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
