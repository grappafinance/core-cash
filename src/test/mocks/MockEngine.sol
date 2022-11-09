// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.0;

import {IMarginEngine} from "../../interfaces/IMarginEngine.sol";
import {BaseEngine} from "../../core/engines/BaseEngine.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../../config/enums.sol";
import "../../config/types.sol";
import "../../config/errors.sol";

/**
 * @title   MockEngine
 * @notice  Implement execute to test all flow in BaseEngine
 */
contract MockEngine is BaseEngine {
    bool public isAboveWater;

    uint80 public mockPayout;
    uint8 private mockPayoutCollatId;

    constructor(address _grappa, address _option) BaseEngine(_grappa, _option) {}

    function setIsAboveWater(bool _isAboveWater) external {
        isAboveWater = _isAboveWater;
    }

    function setPayout(uint80 _payout) external {
        mockPayout = _payout;
    }

    function setPayoutCollatId(uint8 _id) external {
        mockPayoutCollatId = _id;
    }

    function _getAccountPayout(
        address /*subAccount*/
    ) internal view override returns (uint8, uint80) {
        return (mockPayoutCollatId, mockPayout);
    }

    /**
     * @notice default behavior of the engine 'execute' function
     * @dev put the default implementation here to have unit tests for all token transfer flows
     */
    function execute(address _subAccount, ActionArgs[] calldata actions) public virtual nonReentrant {
        _assertCallerHasAccess(_subAccount);

        // update the account and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShortIntoAccount)
                _mintOptionIntoAccount(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else if (actions[i].action == ActionType.AddLong) _addOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveLong) _removeOption(_subAccount, actions[i].data);

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
        if (!_isAccountAboveWater(_subAccount)) revert BM_AccountUnderwater();
    }

    function _isAccountAboveWater(
        address /*_subAccount*/
    ) internal view override returns (bool) {
        return isAboveWater;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
