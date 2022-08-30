// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../../shared/AdvancedFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

contract AdvanceEngineGernal is AdvancedFixture {
    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);
    }

    function testCannotCallAddLong() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.AddLong, data: abi.encode(0)});

        vm.expectRevert(EG_UnsupportedAction.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallRemoveLong() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.RemoveLong, data: abi.encode(0)});

        vm.expectRevert(EG_UnsupportedAction.selector);
        engine.execute(address(this), actions);
    }
}
