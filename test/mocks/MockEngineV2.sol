// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/errors.sol";

/**
 * @title   MockEngineV2
 * @notice  Mock contract to test upgradability
 */
contract MockEngineV2 is UUPSUpgradeable {
    function version() external pure returns (uint256) {
        return 2;
    }

    /**
     * @dev future version that cannot be upgraded in the future
     *
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal pure override {
        revert("not upgrdable anymore");
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
