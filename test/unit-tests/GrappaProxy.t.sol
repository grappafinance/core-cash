// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Grappa} from "../../src/core/Grappa.sol";
import {GrappaProxy} from "../../src/core/GrappaProxy.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

import {MockGrappaV2} from "../mocks/MockGrappaV2.sol";

import "../../src/config/errors.sol";
import "../../src/config/enums.sol";
import "../../src/config/constants.sol";

/**
 * @dev test on proxy contract
 */
contract GrappaProxyTest is Test {
    Grappa public implementation;
    Grappa public grappa;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);

        implementation = new Grappa(address(0));
        bytes memory data = abi.encodeWithSelector(Grappa.initialize.selector, address(this));

        grappa = Grappa(address(new GrappaProxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize(address(this));
    }

    function testProxyOwnerIsSelf() public {
        assertEq(grappa.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        grappa.initialize(address(this));
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        grappa.upgradeTo(address(1));
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockGrappaV2 v2 = new MockGrappaV2();

        grappa.upgradeTo(address(v2));

        assertEq(MockGrappaV2(address(grappa)).version(), 2);
    }

    function testCannotUpgradeTov3() public {
        MockGrappaV2 v2 = new MockGrappaV2();
        MockGrappaV2 v3 = new MockGrappaV2();

        grappa.upgradeTo(address(v2));

        vm.expectRevert("not upgrdable anymore");
        grappa.upgradeTo(address(v3));
    }

    function testProxyCanDecideInitRule() public {
        // deploy a new proxy that doesn't call initialize when deployed
        Grappa proxy2 = Grappa(address(new GrappaProxy(address(implementation), "")));

        // cannot init with 0 as owner
        vm.expectRevert();
        proxy2.initialize(address(0));

        proxy2.initialize(address(0xaa));
        assertEq(proxy2.owner(), address(0xaa));
    }
}
