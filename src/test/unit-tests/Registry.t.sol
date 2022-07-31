// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import "forge-std/Test.sol";

import {Registry} from "../../core/Registry.sol";

import {MockERC20} from "../mocks/MockERC20.sol";

import "../../config/enums.sol";
import "../../config/types.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";

import "forge-std/console2.sol";

/**
 * @dev test oracle functions, mocking pricers
 */
contract RegistryTest is Test {
    Registry public registry;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);
        registry = new Registry();
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        registry.registerAsset(address(weth));
    }

    function testRegisterAssetFromId1() public {
        uint8 id = registry.registerAsset(address(weth));
        assertEq(id, 1);

        assertEq(registry.assetIds(address(weth)), id);
    }

    function testRegisterAssetRecordDecimals() public {
        uint8 id = registry.registerAsset(address(weth));

        (address addr, uint8 decimals) = registry.assets(id);

        assertEq(addr, address(weth));
        assertEq(decimals, 18);
    }

    function testCannotRegistrySameAssetTwice() public {
        registry.registerAsset(address(weth));
        vm.expectRevert(Registry.AssetAlreadyRegistered.selector);
        registry.registerAsset(address(weth));
    }
}
