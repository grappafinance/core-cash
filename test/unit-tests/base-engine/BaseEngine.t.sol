// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {MockedBaseEngineSetup} from "./MockedBaseEngineSetup.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../src/config/enums.sol";
import "../../../src/config/types.sol";
import "../../../src/config/constants.sol";
import "../../../src/config/errors.sol";

contract BaseEngineTest is MockedBaseEngineSetup {
    address delegate = address(0xdd);

    function testSetAccess() public {
        engine.setAccountAccess(delegate, 10);

        engine.setIsAboveWater(true);

        vm.prank(delegate);
        ActionArgs[] memory actions = new ActionArgs[](0);
        engine.execute(address(this), actions);

        uint160 mask = uint160(address(this)) | 0xFF;
        assertEq(engine.allowedExecutionLeft(mask, delegate), 9);
    }

    function testSetAccessForSubAccounts() public {
        engine.setAccountAccess(delegate, 10);

        engine.setIsAboveWater(true);

        vm.prank(delegate);
        ActionArgs[] memory actions = new ActionArgs[](0);

        // can operate on subaccount
        address subAccount = address(uint160(address(this)) - 1);
        engine.execute(subAccount, actions);

        uint160 mask = uint160(address(this)) | 0xFF;
        assertEq(engine.allowedExecutionLeft(mask, delegate), 9);
    }

    function testRevokeAccess() public {
        engine.setAccountAccess(delegate, 10);

        vm.startPrank(delegate);
        engine.revokeSelfAccess(address(this));

        vm.expectRevert(NoAccess.selector);
        ActionArgs[] memory actions = new ActionArgs[](0);
        engine.execute(address(this), actions);
    }

    function testCanRequestPayoutFromGrappa() public {
        usdc.mint(address(engine), 1000 * UNIT);

        vm.prank(address(grappa));
        engine.payCashValue(address(usdc), address(this), 1000 * UNIT);

        assertEq(usdc.balanceOf(address(this)), 1000 * UNIT);
    }

    function testCannotRequestPayoutFromRandomAddress() public {
        vm.expectRevert(NoAccess.selector);
        engine.payCashValue(address(usdc), address(this), 1000 * UNIT);
    }

    // just for coverage
    function testOnReceive() public {
        uint256[] memory data = new uint256[](0);
        assertEq(engine.onERC1155BatchReceived(address(0), address(0), data, data, ""), engine.onERC1155BatchReceived.selector);
    }
}
