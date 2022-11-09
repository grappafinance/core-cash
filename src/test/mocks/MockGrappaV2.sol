// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

import "../../config/enums.sol";
import "../../config/types.sol";
import "../../config/errors.sol";

/**
 * @title   MockGrappaV2
 * @notice  Mock contract to test upgradability
 */
contract MockGrappaV2 is UUPSUpgradeable {

    function version() external pure returns (uint256) {
      return 2;
    }

    /**
     * @dev future version that cannot be upgraded in the future
     **/ 
    function _authorizeUpgrade(address /*newImplementation*/) internal pure override {
        revert("not upgrdable anymore");
    }
}
