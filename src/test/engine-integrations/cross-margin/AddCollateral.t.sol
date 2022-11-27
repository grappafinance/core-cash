// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestAddCollateral_CM is CrossMarginFixture {
    function setUp() public {
        // approve engine
        usdc.mint(address(this), 1000_000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);
        usdc.mint(address(alice), 100 * 1e18);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);
        weth.mint(address(alice), 100 * 1e18);
    }

    function testAddCollateralChangeStorage() public {
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);
        (,, Balance[] memory _collaters) = engine.marginAccounts(address(this));

        assertEq(_collaters[0].collateralId, usdcId);
        assertEq(_collaters[0].amount, depositAmount);
    }

    function testAddCollateralMoveBalance() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount);
    }

    function testAddCollateralLoopMoveBalances() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));
        uint256 depositAmount = 500 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount * 2);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount * 2);
    }

    function testAddMultipleCollateralHasNoSideEffects() public {
        uint256 engineUsdcBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myUsdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 aliceUsdcBalanceBefore = usdc.balanceOf(address(alice));
        uint256 usdcDepositAmount = 500 * 1e6;
        uint256 engineEthBalanceBefore = weth.balanceOf(address(engine));
        uint256 myEthBalanceBefore = weth.balanceOf(address(this));
        uint256 aliceEthBalanceBefore = weth.balanceOf(address(alice));
        uint256 ethDepositAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount);
        actions[1] = createAddCollateralAction(wethId, address(this), ethDepositAmount);
        engine.execute(address(this), actions);

        uint256 engineUsdcBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myUsdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 aliceUsdcBalanceAfter = usdc.balanceOf(address(alice));
        uint256 engineEthBalanceAfter = weth.balanceOf(address(engine));
        uint256 myEthBalanceAfter = weth.balanceOf(address(this));
        uint256 aliceEthBalanceAfter = weth.balanceOf(address(alice));

        assertEq(myEthBalanceBefore - myEthBalanceAfter, ethDepositAmount);
        assertEq(engineEthBalanceAfter - engineEthBalanceBefore, ethDepositAmount);
        assertEq(myUsdcBalanceBefore - myUsdcBalanceAfter, usdcDepositAmount);
        assertEq(engineUsdcBalanceAfter - engineUsdcBalanceBefore, usdcDepositAmount);
        assertEq(aliceUsdcBalanceBefore, aliceUsdcBalanceAfter);
        assertEq(aliceEthBalanceBefore, aliceEthBalanceAfter);
    }

    function testCanAddDifferentCollateralToSameAccount() public {
        uint256 usdcAmount = 500 * 1e6;
        uint256 wethAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcAmount);
        actions[1] = createAddCollateralAction(wethId, address(this), wethAmount);

        engine.execute(address(this), actions);

        (,, Balance[] memory _collaterals) = engine.marginAccounts(address(this));

        assertEq(_collaterals.length, 2);
        assertEq(_collaterals[0].collateralId, usdcId);
        assertEq(_collaterals[0].amount, usdcAmount);
        assertEq(_collaterals[1].collateralId, wethId);
        assertEq(_collaterals[1].amount, wethAmount);
    }

    function testCannotAddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(alice), 100);
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }
}
