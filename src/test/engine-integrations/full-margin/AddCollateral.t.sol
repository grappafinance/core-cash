// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {FullMarginFixture} from "../../shared/FullMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestAddCollateral_FM is FullMarginFixture {
    function setUp() public {
        // approve engine
        usdc.mint(address(this), 1000_000_000 * 1e6);
        usdc.approve(address(fmEngine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(fmEngine), type(uint256).max);
    }

    function testAddCollateralChangeStorage() public {
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(fmEngineId, address(this), actions);
        (, , uint8 _collateralId, uint80 _collateralAmount) = fmEngine.marginAccounts(address(this));

        assertEq(_collateralId, usdcId);
        assertEq(_collateralAmount, depositAmount);
    }

    function testAddCollateralMoveBalance() public {
        uint256 engineBalanceBefoe = usdc.balanceOf(address(fmEngine));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(fmEngineId, address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(fmEngine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefoe - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefoe, depositAmount);
    }

    function testAddCollateralLoopMoveBalances() public {
        uint256 engineBalanceBefoe = usdc.balanceOf(address(fmEngine));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));
        uint256 depositAmount = 500 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount);
        grappa.execute(fmEngineId, address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(fmEngine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefoe - myBalanceAfter, depositAmount * 2);
        assertEq(engineBalanceAfter - engineBalanceBefoe, depositAmount * 2);
    }

    function testCannotAddDifferentProductToSameAccount() public {
        uint256 usdcAmount = 500 * 1e6;
        uint256 wethAmount = 10 * 1e18;

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcAmount);
        actions[1] = createAddCollateralAction(wethId, address(this), wethAmount);

        vm.expectRevert(AM_WrongCollateralId.selector);
        grappa.execute(fmEngineId, address(this), actions);
    }

    function testCannotAddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(alice), 100);
        vm.expectRevert(GP_InvalidFromAddress.selector);
        grappa.execute(fmEngineId, address(this), actions);
    }
}
