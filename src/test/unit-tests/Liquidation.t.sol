// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

import "forge-std/console2.sol";

contract TestLiquidateCall is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private initialCollateral;

    address private accountId;

    function setUp() public {
        // setup account for alice
        usdc.mint(alice, 1000_000 * 1e6);

        vm.startPrank(alice);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 7 days;

        oracle.setSpotPrice(3500 * UNIT);

        // mint option
        initialCollateral = 700 * 1e6;

        strike = uint64(4000 * UNIT);

        accountId = alice;

        tokenId = getTokenId(TokenType.CALL, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, alice, initialCollateral);
        // give optoin to this address, so it can liquidate alice
        actions[1] = createMintAction(tokenId, address(this), amount);

        // mint option
        grappa.execute(accountId, actions);

        vm.stopPrank();
    }

    function testCannotLiquidateHealthyVault() public {
        vm.expectRevert(AccountIsHealthy.selector);
        grappa.liquidate(accountId, amount, 0);
    }

    function testCannotLiquidateVaultWithPuts() public {
        oracle.setSpotPrice(3800 * UNIT);

        vm.expectRevert(WrongLiquidationAmounts.selector);
        grappa.liquidate(accountId, 0, amount);
    }

    function testPartiallyLiquidateTheVault() public {
        oracle.setSpotPrice(3800 * UNIT);

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 optionBalanceBefore = option.balanceOf(address(this), tokenId);
        
        uint64 liquidateAmount = amount / 2;
        grappa.liquidate(accountId, liquidateAmount, 0);

        uint256 expectCollateralToGet = initialCollateral / 2;
        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 optionBalanceAfter = option.balanceOf(address(this), tokenId);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, expectCollateralToGet);
        assertEq(optionBalanceBefore - optionBalanceAfter, liquidateAmount);
    }

    function testFullyLiquidateTheVault() public {
        oracle.setSpotPrice(3800 * UNIT);

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 optionBalanceBefore = option.balanceOf(address(this), tokenId);

        grappa.liquidate(accountId, amount, 0);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 optionBalanceAfter = option.balanceOf(address(this), tokenId);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, initialCollateral);
        assertEq(optionBalanceBefore - optionBalanceAfter, amount);

        // vault should be reset
        (
            uint256 shortCallId,
            ,
            uint64 shortCallAmount,
            ,
            uint80 collateralAmount,
            uint8 collateralId
        ) = grappa.marginAccounts(accountId);

        assertEq(shortCallId, 0);
        assertEq(shortCallAmount, 0);
        assertEq(collateralAmount, 0);
        assertEq(collateralId, 0);
    }
}

contract TestLiquidatePut is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private initialCollateral;

    address private accountId;

    function setUp() public {
        // setup account for alice
        usdc.mint(alice, 1000_000 * 1e6);

        vm.startPrank(alice);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 7 days;

        oracle.setSpotPrice(4000 * UNIT);

        // mint option
        initialCollateral = 700 * 1e6;

        strike = uint64(3500 * UNIT);

        accountId = alice;

        tokenId = getTokenId(TokenType.PUT, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, alice, initialCollateral);
        // give optoin to this address, so it can liquidate alice
        actions[1] = createMintAction(tokenId, address(this), amount);

        // mint option
        grappa.execute(accountId, actions);

        vm.stopPrank();
    }

    function testCannotLiquidateHealthyVault() public {
        vm.expectRevert(AccountIsHealthy.selector);
        grappa.liquidate(accountId, 0, amount);
    }

    function testCannotLiquidateVaultWithCalls() public {
        oracle.setSpotPrice(3600 * UNIT);

        vm.expectRevert(WrongLiquidationAmounts.selector);
        grappa.liquidate(accountId, amount, 0);
    }

    function testPartiallyLiquidateTheVault() public {
        oracle.setSpotPrice(3600 * UNIT);

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 optionBalanceBefore = option.balanceOf(address(this), tokenId);
        
        uint64 liquidateAmount = amount / 2;
        grappa.liquidate(accountId, 0, liquidateAmount);

        uint256 expectCollateralToGet = initialCollateral / 2;
        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 optionBalanceAfter = option.balanceOf(address(this), tokenId);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, expectCollateralToGet);
        assertEq(optionBalanceBefore - optionBalanceAfter, liquidateAmount);
    }

    function testFullyLiquidateTheVault() public {
        oracle.setSpotPrice(3600 * UNIT);

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 optionBalanceBefore = option.balanceOf(address(this), tokenId);

        grappa.liquidate(accountId, 0, amount);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
        uint256 optionBalanceAfter = option.balanceOf(address(this), tokenId);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, initialCollateral);
        assertEq(optionBalanceBefore - optionBalanceAfter, amount);

        // vault should be reset
        (
            uint256 shortCallId,
            ,
            uint64 shortCallAmount,
            ,
            uint80 collateralAmount,
            uint8 collateralId
        ) = grappa.marginAccounts(accountId);

        assertEq(shortCallId, 0);
        assertEq(shortCallAmount, 0);
        assertEq(collateralAmount, 0);
        assertEq(collateralId, 0);
    }
}
