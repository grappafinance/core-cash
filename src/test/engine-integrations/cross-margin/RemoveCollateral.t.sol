// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
// import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestRemoveCollateral_CM is CrossMarginFixture {
    uint256 private depositAmount = 1000 * 1e6;

    function setUp() public {
        // approve engine
        usdc.mint(address(this), 1000_000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);
    }

    function testRemoveCollateralChangeStorage() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);
        (, , Balance[] memory _collaterals) = engine.marginAccounts(address(this));

        assertEq(_collaterals.length, 0);
    }

    function testRemoveCollateralRetainBalances() public {
        uint256 wethDepositAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), wethDepositAmount);
        actions[1] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);
        (, , Balance[] memory _collaterals) = engine.marginAccounts(address(this));

        assertEq(_collaterals.length, 1);
        assertEq(_collaterals[0].collateralId, wethId);
        assertEq(_collaterals[0].amount, wethDepositAmount);
    }

    function testRemoveCollateralMoveBalance() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceAfter - myBalanceBefore, depositAmount);
        assertEq(engineBalanceBefore - engineBalanceAfter, depositAmount);
    }

    function testCannotRemoveDifferentCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, wethId, address(this));

        vm.expectRevert(CM_WrongCollateralId.selector);
        engine.execute(address(this), actions);
    }

    function testCannotRemoveMoreThanOwn() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount + 1, usdcId, address(this));

        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testMultipleCollateralsAddRemove() public {
        uint256 depositAmountUSDC = 1 * 1e6;
        uint256 depositAmountETH = 1 * 1e18;

        // remove the initial deposit amount from setup
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        // no collaterals should remain from setup
        assertEq(collaterals.length, 0);

        //Add each collateral twice
        actions = new ActionArgs[](4);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmountUSDC);
        actions[1] = createAddCollateralAction(wethId, address(this), depositAmountETH);
        actions[2] = createAddCollateralAction(usdcId, address(this), depositAmountUSDC);
        actions[3] = createAddCollateralAction(wethId, address(this), depositAmountETH);

        engine.execute(address(this), actions);

        (,, collaterals) = engine.marginAccounts(address(this));

        // check amounts
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, 2 * depositAmountUSDC);
        assertEq(collaterals[1].collateralId, wethId);
        assertEq(collaterals[1].amount, 2 * depositAmountETH);

        // we should have 2 instead of 4 array slots
        assertEq(collaterals.length, 2);

        // remove half of each collateral
        actions = new ActionArgs[](2);
        actions[0] = createRemoveCollateralAction(depositAmountETH, wethId, address(this));
        actions[1] = createRemoveCollateralAction(depositAmountUSDC, usdcId, address(this));
        engine.execute(address(this), actions);

        (,, collaterals) = engine.marginAccounts(address(this));

        // check half has been removed
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, depositAmountUSDC);
        assertEq(collaterals[1].collateralId, wethId);
        assertEq(collaterals[1].amount, depositAmountETH);

        // remove the remaining USDC
        actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmountUSDC, usdcId, address(this));
        engine.execute(address(this), actions);

        (,, collaterals) = engine.marginAccounts(address(this));

        // check remaining is now eth and amount matches
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, depositAmountETH);

        // USDC should have been removed from the array
        assertEq(collaterals.length, 1);

        // add both collaterals again
        actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmountUSDC);
        actions[1] = createAddCollateralAction(wethId, address(this), depositAmountETH);
        engine.execute(address(this), actions);

        (,, collaterals) = engine.marginAccounts(address(this));

        // collaterals should have reversed position since eth was removed and re-added
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, depositAmountETH * 2);
        assertEq(collaterals[1].collateralId, usdcId);
        assertEq(collaterals[1].amount, depositAmountUSDC);

        // remove all collaterals
        actions = new ActionArgs[](2);
        actions[0] = createRemoveCollateralAction(depositAmountETH * 2, wethId, address(this));
        actions[1] = createRemoveCollateralAction(depositAmountUSDC, usdcId, address(this));
        engine.execute(address(this), actions);

        (,, collaterals) = engine.marginAccounts(address(this));

        // nothing should be left
        assertEq(collaterals.length, 0);
    }
}
