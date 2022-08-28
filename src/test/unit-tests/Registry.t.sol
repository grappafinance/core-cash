// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import "forge-std/Test.sol";

import {Registry} from "../../core/Registry.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @dev test registry functions
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

    function testReturnAssetsFromProductId() public {
        registry.registerAsset(address(weth));

        uint32 product = registry.getProductId(0, address(weth), address(0), address(weth));

        (, address underlying, address strike, address collateral, uint8 collatDecimals) = registry
            .getDetailFromProductId(product);

        assertEq(underlying, address(weth));

        // strike is empty
        assertEq(strike, address(0));
        assertEq(underlying, address(weth));
        assertEq(collateral, address(weth));
        assertEq(collatDecimals, 18);
    }
}

/**
 * @dev test registry functions around registering engines
 */
contract RegisterEngineTest is Test {
    Registry public registry;
    address private engine1;

    constructor() {
        engine1 = address(1);
        registry = new Registry();
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        registry.registerEngine(engine1);
    }

    function testRegisterEngineFromId1() public {
        uint8 id = registry.registerEngine(engine1);
        assertEq(id, 1);

        assertEq(registry.amEngineIds(engine1), id);
    }

    function testCannotRegistrySameAssetTwice() public {
        registry.registerEngine(engine1);
        vm.expectRevert(Registry.MarginEngineAlreadyRegistered.selector);
        registry.registerEngine(engine1);
    }

    function testReturnEngineFromProductId() public {
        uint8 id = registry.registerEngine(engine1);

        uint32 product = registry.getProductId(id, address(0), address(0), address(0));

        (address engine, , , , ) = registry.getDetailFromProductId(product);

        assertEq(engine, engine1);
    }
}
