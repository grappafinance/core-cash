// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import {IMarginEngine} from "../../src/interfaces/IMarginEngine.sol";

import {ActionArgs} from "../../src/config/types.sol";

/**
 * @title   MockEngine
 * @notice  Mock contract to test grappa payout functionality
 */
contract MockEngine is IMarginEngine {
    function execute(address _subAccount, ActionArgs[] calldata actions) external {}

    function payCashValue(address _asset, address _recipient, uint256 _amount) external {
        IERC20Metadata(_asset).transfer(_recipient, _amount);
    }
}
