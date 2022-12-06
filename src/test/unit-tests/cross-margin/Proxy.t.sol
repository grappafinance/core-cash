// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import "../../../core/engines/cross-margin/CrossMarginEngine.sol";
import "../../../core/engines/cross-margin/CrossMarginEngineProxy.sol";

import {MockOracle} from "../../mocks/MockOracle.sol";
import {MockEngineV2} from "../../mocks/MockEngineV2.sol";

import "../../../config/errors.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract EngineProxyTest is Test {
    CrossMarginEngine public implementation;
    CrossMarginEngine public engine;

    constructor() {
        implementation = new CrossMarginEngine(address(0), address(0));
        bytes memory data = abi.encode(CrossMarginEngine.initialize.selector);

        engine = CrossMarginEngine(address(new CrossMarginEngineProxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize();
    }

    function testProxyOwnerIsSelf() public {
        assertEq(engine.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        engine.initialize();
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        engine.upgradeTo(address(0));
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockEngineV2 v2 = new MockEngineV2();

        engine.upgradeTo(address(v2));

        assertEq(MockEngineV2(address(engine)).version(), 2);
    }

    function testCannotUpgradeTov3() public {
        MockEngineV2 v2 = new MockEngineV2();
        MockEngineV2 v3 = new MockEngineV2();

        engine.upgradeTo(address(v2));

        vm.expectRevert("not upgrdable anymore");
        engine.upgradeTo(address(v3));
    }
}
