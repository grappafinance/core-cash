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

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);
    }

    function testCannotGetPhysicalSettlementPerTokenForCashSettledToken() public {
        tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        vm.expectRevert(PS_InvalidSettlementType.selector);
        engine.getPhysicalSettlementPerToken(tokenId);
    }

    function testGetsNothingFromOptionPastSettlementWindow() public {
        tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

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
        engine.setSettlementWindow(1 hours);

        tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

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

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);
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

        expiry = block.timestamp + 14 days;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);
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
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettlePhysicalShortPositions_CM is CrossMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint64 private strike;
    uint256 private wethDepositAmount = 1 ether;
    uint256 private usdcDepositAmount = 4000 * 1e6;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);
    }

    function testSellerCannotClearCallDebtAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        (Position[] memory shortsBefore,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shortsAfter,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shortsBefore.length, shortsAfter.length);
        assertEq(collateralsBefore.length, collateralsAfter.length);
    }

    function testSellerCanClearCallDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount);
    }

    function testSellerCanClearPartialCallDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry);

        vm.startPrank(alice);
        usdc.mint(alice, 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        grappa.settle(alice, tokenId, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + engine.settlementWindow());

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount / 2);
    }

    function testSellerCannotClearPutDebtAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        (Position[] memory shortsBefore,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shortsAfter,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shortsBefore.length, shortsAfter.length);
        assertEq(collateralsBefore.length, collateralsAfter.length);
    }

    function testSellerCanClearPutDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount);
    }

    function testSellerCanClearPartialPutDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry);

        vm.startPrank(alice);
        weth.mint(alice, 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        grappa.settle(alice, tokenId, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + engine.settlementWindow());

        (,, Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter[0].collateralId, collateralsBefore[0].collateralId);
        assertEq(collateralsAfter[0].amount, collateralsBefore[0].amount / 2);
    }

    function _mintTokens(uint256 tokenId, uint8 collateralId, uint256 depositAmount) internal {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(collateralId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettlePhysicalLongPositions_CM is CrossMarginFixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint64 private strike;
    uint256 private wethDepositAmount = 1 ether;
    uint256 private usdcDepositAmount = 4000 * 1e6;

    function setUp() public {
        weth.mint(alice, 1000 * 1e18);
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        usdc.mint(alice, 1000_000 * 1e6);
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);
    }

    function testHolderCannotClearLongCallAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 0);
    }

    function testSellerCanClearLongCallDebtAfterExpiryBeforeWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);

        _mintTokens(tokenId, wethId, wethDepositAmount);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount);
        actions[1] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount);
    }

    function testHolderCannotClearLongPutAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 0);
    }

    function testSellerCanClearPutDebtAfterWindowClosed() public {
        uint256 tokenId = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(tokenId, usdcId, usdcDepositAmount);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), wethDepositAmount);
        actions[1] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount);
    }

    function _mintTokens(uint256 tokenId, uint8 collateralId, uint256 depositAmount) internal {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(collateralId, alice, depositAmount);
        // give option to alice
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);

        // mint option
        vm.startPrank(alice);
        engine.execute(alice, actions);
        vm.stopPrank();

        // expire option
        vm.warp(expiry);
    }
}
