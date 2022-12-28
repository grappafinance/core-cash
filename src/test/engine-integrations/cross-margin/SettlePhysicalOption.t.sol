// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";
import "../../mocks/MockERC20.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSettlePhysicalOption_CM is CrossMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 1 ether;
    uint16 private issuerId;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);

        issuerId = engine.registerIssuer(address(this));
    }

    function testCannotGetPhysicalSettlementPerTokenForCashSettledToken() public {
        tokenId = getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        vm.expectRevert(PS_InvalidSettlementType.selector);
        engine.getPhysicalSettlementPerToken(tokenId);
    }

    function testGetsNothingFromOptionPastSettlementWindow() public {
        tokenId = getTokenId(DerivativeType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, issuerId);

        vm.warp(expiry + 14 minutes);

        Settlement memory settlement = engine.getPhysicalSettlementPerToken(tokenId);

        assertEq(settlement.debtPerToken, uint256(strike));
        assertEq(settlement.payoutPerToken, depositAmount);

        vm.warp(expiry + 16 minutes);

        settlement = engine.getPhysicalSettlementPerToken(tokenId);

        assertEq(settlement.debtPerToken, 0);
        assertEq(settlement.payoutPerToken, 0);
    }

    function testGetsNothingFromOptionPastCustomSettlementWindow() public {
        engine.setPhysicalSettlementWindow(1 hours);

        tokenId = getTokenId(DerivativeType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, issuerId);

        vm.warp(expiry + 16 minutes);

        Settlement memory settlement = engine.getPhysicalSettlementPerToken(tokenId);

        assertEq(settlement.debtPerToken, uint256(strike));
        assertEq(settlement.payoutPerToken, depositAmount);

        vm.warp(expiry + 61 minutes);

        settlement = engine.getPhysicalSettlementPerToken(tokenId);

        assertEq(settlement.debtPerToken, 0);
        assertEq(settlement.payoutPerToken, 0);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettlePhysicalCoveredCall_CM is CrossMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 1 ether;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        uint16 issuerId = engine.registerIssuer(address(this));

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(DerivativeType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, issuerId);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetCallPayoutAndDeductedDebt() public {
        vm.startPrank(alice);
        usdc.mint(alice, 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        (Position[] memory beforeShorts,,) = engine.marginAccounts(address(this));

        vm.startPrank(alice);
        (uint256 debt, uint256 payout) = grappa.settle(alice, tokenId, amount);
        vm.stopPrank();

        uint256 expectedDebt = uint256(strike);
        uint256 expectedPayout = uint256(amount) * 1e18 / UNIT;

        assertEq(debt, expectedDebt);
        assertEq(payout, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(usdcBefore, usdcAfter + expectedDebt);

        assertEq(optionBefore, optionAfter + amount);

        (Position[] memory afterShorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(beforeShorts.length, 1);
        assertEq(afterShorts.length, 0);

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, expectedDebt);
    }

    function testShouldGetCallPayoutAndDeductedDebtFromSender() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(address(this));
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        (Position[] memory beforeShorts,,) = engine.marginAccounts(address(this));

        (uint256 debt, uint256 payout) = grappa.settle(alice, tokenId, amount);

        uint256 expectedDebt = uint256(strike);
        uint256 expectedPayout = uint256(amount) * 1e18 / UNIT;

        assertEq(debt, expectedDebt);
        assertEq(payout, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(address(this));
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(usdcBefore, usdcAfter + expectedDebt);

        assertEq(optionBefore, optionAfter + amount);

        (Position[] memory afterShorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(beforeShorts.length, 1);
        assertEq(afterShorts.length, 0);

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, expectedDebt);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettlePhysicalCollateralizedPut_CM is CrossMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 2000 * 1e6;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        uint16 issuerId = engine.registerIssuer(address(this));

        expiry = block.timestamp + 14 days;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(DerivativeType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, issuerId);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetPutPayoutAndDeductedDebt() public {
        vm.startPrank(alice);
        weth.mint(alice, 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        (Position[] memory beforeShorts,,) = engine.marginAccounts(address(this));

        vm.startPrank(alice);
        (uint256 debt, uint256 payout) = grappa.settle(alice, tokenId, amount);
        vm.stopPrank();

        uint256 expectedDebt = uint256(amount) * 1e18 / UNIT;
        uint256 expectedPayout = uint256(strike);

        assertEq(debt, expectedDebt);
        assertEq(payout, expectedPayout);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter + expectedDebt);
        assertEq(usdcAfter, usdcBefore + expectedPayout);

        assertEq(optionBefore, optionAfter + amount);

        (Position[] memory afterShorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(beforeShorts.length, 1);
        assertEq(afterShorts.length, 0);

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, expectedDebt);
    }

    function testShouldGetPutPayoutAndDeductedDebtFromSender() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        vm.startPrank(alice);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        (Position[] memory beforeShorts,,) = engine.marginAccounts(address(this));

        (uint256 debt, uint256 payout) = grappa.settle(alice, tokenId, amount);

        uint256 expectedDebt = uint256(amount) * 1e18 / UNIT;
        uint256 expectedPayout = uint256(strike);

        assertEq(debt, expectedDebt);
        assertEq(payout, expectedPayout);

        uint256 wethAfter = weth.balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter + expectedDebt);
        assertEq(usdcAfter, usdcBefore + expectedPayout);

        assertEq(optionBefore, optionAfter + amount);

        (Position[] memory afterShorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(beforeShorts.length, 1);
        assertEq(afterShorts.length, 0);

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, expectedDebt);
    }
}
