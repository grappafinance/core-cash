// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "../../shared/Fixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract TestAddCollateral is Fixture {
    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(grappa), type(uint256).max);
    }

    function testAddCollateralChangeStorage() public {
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(engineId, address(this), actions);
        (, , , , uint80 _collateralAmount, uint8 _collateralId) = marginEngine.marginAccounts(address(this));

        assertEq(_collateralId, usdcId);
        assertEq(_collateralAmount, depositAmount);
    }

    function testAddCollateralMoveBalance() public {
        uint256 grappaBalanceBefoe = usdc.balanceOf(address(grappa));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(engineId, address(this), actions);

        uint256 grappaBalanceAfter = usdc.balanceOf(address(grappa));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefoe - myBalanceAfter, depositAmount);
        assertEq(grappaBalanceAfter - grappaBalanceBefoe, depositAmount);
    }

    function testAddCollateralLoopMoveBalances() public {
        uint256 grappaBalanceBefoe = usdc.balanceOf(address(grappa));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));
        uint256 depositAmount = 500 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(engineId, address(this), actions);

        uint256 grappaBalanceAfter = usdc.balanceOf(address(grappa));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefoe - myBalanceAfter, depositAmount * 2);
        assertEq(grappaBalanceAfter - grappaBalanceBefoe, depositAmount * 2);
    }

    function testCannotAddDifferentProductToSameAccount() public {
        uint256 usdcAmount = 500 * 1e6;
        uint256 wethAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcAmount);
        actions[1] = createAddCollateralAction(wethId, address(this), wethAmount);

        vm.expectRevert(MA_WrongCollateralId.selector);
        grappa.execute(engineId, address(this), actions);
    }

    function testCannotAddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(alice), 100);
        vm.expectRevert(MA_InvalidFromAddress.selector);
        grappa.execute(engineId, address(this), actions);
    }
}
