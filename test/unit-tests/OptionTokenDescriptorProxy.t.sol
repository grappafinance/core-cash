// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {CashOptionTokenDescriptor} from "../../src/core/CashOptionTokenDescriptor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

import {MockTokenDescriptorV2} from "../mocks/MockCashOptionTokenDescriptorV2.sol";

import "../../src/config/errors.sol";
import "../../src/config/enums.sol";
import "../../src/config/constants.sol";

/**
 * @dev test on implementation contract
 */
contract OptionProxyTest is Test {
    CashOptionTokenDescriptor public implementation;
    CashOptionTokenDescriptor public descriptor;

    constructor() {
        implementation = new CashOptionTokenDescriptor();
        bytes memory data = abi.encode(CashOptionTokenDescriptor.initialize.selector);

        descriptor = CashOptionTokenDescriptor(address(new ERC1967Proxy(address(implementation), data)));
    }

    function testImplementationContractOwnerIsZero() public {
        assertEq(implementation.owner(), address(0));
    }

    function testImplementationIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        implementation.initialize();
    }

    function testProxyOwnerIsCorrect() public {
        assertEq(descriptor.owner(), address(this));
    }

    function testProxyIsInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        descriptor.initialize();
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.prank(address(0xaa));
        vm.expectRevert("Ownable: caller is not the owner");
        descriptor.upgradeTo(address(1));
    }

    function testGetUrl() public {
        assertEq(descriptor.tokenURI(0), "https://grappa.finance/token/0");
        assertEq(descriptor.tokenURI(200), "https://grappa.finance/token/200");
    }

    function testCanUpgradeToAnotherUUPSContract() public {
        MockTokenDescriptorV2 v2 = new MockTokenDescriptorV2();

        descriptor.upgradeTo(address(v2));

        assertEq(descriptor.tokenURI(0), "https://grappa.finance/token/v2/0");
        assertEq(descriptor.tokenURI(200), "https://grappa.finance/token/v2/200");
    }

    function testProxyCanInitLater() public {
        // don't set init call as data
        CashOptionTokenDescriptor testDescriptor =
            CashOptionTokenDescriptor(address(new ERC1967Proxy(address(implementation), "")));
        assertEq(testDescriptor.owner(), address(0));

        testDescriptor.initialize();
        assertEq(testDescriptor.owner(), address(this));
    }
}
