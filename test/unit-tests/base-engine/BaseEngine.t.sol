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

    function testRevokeAccess() public {
        engine.setAccountAccess(delegate, 10);

        vm.startPrank(delegate);
        engine.revokeSelfAccess(address(this));

        vm.expectRevert(NoAccess.selector);
        ActionArgs[] memory actions = new ActionArgs[](0);
        engine.execute(address(this), actions);
    }
}
