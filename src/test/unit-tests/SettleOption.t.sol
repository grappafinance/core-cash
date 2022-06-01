// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";
import {ActionHelper} from "src/test/shared/ActionHelper.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";

contract TestSettleCall is Fixture, ActionHelper {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike - 1);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(expiryPrice) - strike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }
}

contract TestSettlePut is Fixture, ActionHelper {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike + 1);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }
}

contract TestSettleCallSpread is Fixture, ActionHelper {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(4000 * UNIT);
        shortStrike = uint64(4200 * UNIT);

        tokenId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(longStrike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testShouldGetPayoutDiffereceBetweenSpotAndLongStrike() public {
        // expires in the money, not higher than upper bond
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(expiryPrice) - longStrike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testPayoutShouldBeCappedAtShortStrike() public {
        // expires in the money, higher than upper bond
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(shortStrike) - longStrike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }
}

contract TestSettlePutSpread is Fixture, ActionHelper {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(2000 * UNIT);
        shortStrike = uint64(1800 * UNIT);

        tokenId = getTokenId(TokenType.PUT_SPREAD, productId, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(longStrike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testShouldGetPayoutDiffereceBetweenSpotAndLongStrike() public {
        // expires in the money, not lower than lower bond
        uint256 expiryPrice = 1900 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = longStrike - uint64(expiryPrice);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testPayoutShouldBeCappedAtShortStrike() public {
        // expires in the money, lower than lower bond
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = longStrike - uint64(shortStrike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }
}
