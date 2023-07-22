// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import {BaseEngine} from "../../src/core/engines/BaseEngine.sol";
import {OptionTransferable} from "../../src/core/engines/mixins/OptionTransferable.sol";

import "../../src/config/types.sol";

/**
 * @title   MockTransferableEngine
 * @notice  Implement execute to test all flow in OptionTransferable
 */
contract MockTransferableEngine is BaseEngine, OptionTransferable {
    constructor(address _grappa, address _option) BaseEngine(_grappa, _option) {}

    mapping(address => bool) isAboveWater;

    /**
     * @notice default behavior of the engine 'execute' function
     * @dev put the default implementation here to have unit tests for all token transfer flows
     */
    function execute(address _subAccount, ActionArgs[] calldata actions) external {
        // update the account and do external calls on the flight
        for (uint256 i; i < actions.length;) {
            if (actions[i].action == ActionType.AddCollateral) {
                _addCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.RemoveCollateral) {
                _removeCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.MintShort) {
                _mintOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.BurnShort) {
                _burnOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.MintShortIntoAccount) {
                _mintOptionIntoAccount(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferCollateral) {
                _transferCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferLong) {
                _transferLong(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferShort) {
                _transferShort(_subAccount, actions[i].data);
            }

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
    }

    function _isAccountAboveWater(address _subAccount) internal view override returns (bool) {
        return isAboveWater[_subAccount];
    }

    function _getAccountPayout(address) internal pure override returns (uint8, int80) {
        return (0, 0);
    }

    function setIsAboveWater(address _subAccount, bool _isAboveWater) external {
        isAboveWater[_subAccount] = _isAboveWater;
    }
}
