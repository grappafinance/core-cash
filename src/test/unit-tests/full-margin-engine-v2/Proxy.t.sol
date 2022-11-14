// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../../../core/engines/full-margin-v2/FullMarginEngineV2.sol";

import {MockOracle} from "../../mocks/MockOracle.sol";
import {MockEngineV2} from "../../mocks/MockEngineV2.sol";

import "../../../config/errors.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract EngineProxyTest is Test {
    FullMarginEngineV2 public implementation;
    FullMarginEngineV2 public engine;

    constructor() {
        implementation = new FullMarginEngineV2(address(0), address(0));
        bytes memory data = abi.encode(FullMarginEngineV2.initialize.selector);

        engine = FullMarginEngineV2(address(new ERC1967Proxy(address(implementation), data)));
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
        MockEngineV2 v2 = new MockEngineV2();

        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        engine.upgradeTo(address(v2));
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
