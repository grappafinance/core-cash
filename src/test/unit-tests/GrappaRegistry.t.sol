// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import "forge-std/Test.sol";

import {Grappa} from "../../core/Grappa.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import "../../config/errors.sol";

/**
 * @dev test grappa register related functions
 */
contract GrappaRegistry is Test {
    Grappa public grappa;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);
        grappa = new Grappa(address(0), address(0));
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        grappa.registerAsset(address(weth));
    }

    function testRegisterAssetFromId1() public {
        uint8 id = grappa.registerAsset(address(weth));
        assertEq(id, 1);

        assertEq(grappa.assetIds(address(weth)), id);
    }

    function testRegisterAssetRecordDecimals() public {
        uint8 id = grappa.registerAsset(address(weth));

        (address addr, uint8 decimals) = grappa.assets(id);

        assertEq(addr, address(weth));
        assertEq(decimals, 18);
    }

    function testCannotRegistrySameAssetTwice() public {
        grappa.registerAsset(address(weth));
        vm.expectRevert(GP_AssetAlreadyRegistered.selector);
        grappa.registerAsset(address(weth));
    }

    function testReturnAssetsFromProductId() public {
        grappa.registerAsset(address(weth));

        uint32 product = grappa.getProductId(0, address(weth), address(0), address(weth));

        (, address underlying, address strike, address collateral, uint8 collatDecimals) = grappa
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
 * @dev test grappa functions around registering engines
 */
contract RegisterEngineTest is Test {
    Grappa public grappa;
    address private engine1;

    constructor() {
        engine1 = address(1);
        grappa = new Grappa(address(0), address(0));
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        grappa.registerEngine(engine1);
    }

    function testRegisterEngineFromId1() public {
        uint8 id = grappa.registerEngine(engine1);
        assertEq(id, 1);

        assertEq(grappa.engineIds(engine1), id);
    }

    function testCannotRegistrySameAssetTwice() public {
        grappa.registerEngine(engine1);
        vm.expectRevert(GP_EngineAlreadyRegistered.selector);
        grappa.registerEngine(engine1);
    }

    function testReturnEngineFromProductId() public {
        uint8 id = grappa.registerEngine(engine1);

        uint32 product = grappa.getProductId(id, address(0), address(0), address(0));

        (address engine, , , , ) = grappa.getDetailFromProductId(product);

        assertEq(engine, engine1);
    }
}
