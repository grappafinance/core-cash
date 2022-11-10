// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {Grappa} from "../../core/Grappa.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

import {MockGrappaV2} from "../mocks/MockGrappaV2.sol";

import "../../config/errors.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract GrappaProxyTest is Test {
    Grappa public implementation;
    Grappa public grappa;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);

        implementation = new Grappa(address(0));
        bytes memory data = abi.encode(Grappa.initialize.selector);

        grappa = Grappa(address(new ERC1967Proxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize();
    }

    function testProxyOwnerIsSelf() public {
        assertEq(grappa.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        grappa.initialize();
    }

    function testCannotUpgradeFromNonOwner() public {
        MockGrappaV2 v2 = new MockGrappaV2();

        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        grappa.upgradeTo(address(v2));
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockGrappaV2 v2 = new MockGrappaV2();

        grappa.upgradeTo(address(v2));

        assertEq(MockGrappaV2(address(grappa)).version(), 2);
    }
}
