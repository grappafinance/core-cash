// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";
import "../../mocks/MockERC20.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../utils/Console.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSettleCoveredCall_FMV2 is FullMarginFixtureV2 {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 1 ether;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        expiry = block.timestamp + 14 days;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike - 1);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - strike) / 5000) * (10**(18 - UNIT_DECIMALS));
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);
        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }

    // settlement for sell side

    function testSellerCanClearDebtIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike - 1);

        (, , Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // covered call, underlying and collateral are the same
        // uint256 uIndex = 0;
        uint256 cIndex = 0;

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (Position[] memory shorts, , Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter.length, collateralsBefore.length);
        // assertEq(collateralsAfter[uIndex].collateralId, collateralsBefore[uIndex].collateralId);
        // assertEq(collateralsAfter[uIndex].amount, collateralsBefore[uIndex].amount);
        assertEq(collateralsAfter[cIndex].collateralId, collateralsBefore[cIndex].collateralId);
        assertEq(collateralsAfter[cIndex].amount, collateralsBefore[cIndex].amount);
    }

    function testSellerCollateralIsReducedIfExpiresITM() public {
        // expires out the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - strike) / 5000) * (10**(18 - UNIT_DECIMALS));

        (, , Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // covered call, underlying and collateral are the same
        // uint256 uIndex = 0;
        uint256 cIndex = 0;

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (Position[] memory shorts, , Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter.length, collateralsBefore.length);
        // assertEq(collateralsAfter[uIndex].collateralId, collateralsBefore[uIndex].collateralId);
        // assertEq(collateralsBefore[uIndex].amount - collateralsAfter[uIndex].amount, expectedPayout);
        assertEq(collateralsAfter[cIndex].collateralId, collateralsBefore[cIndex].collateralId);
        assertEq(collateralsBefore[cIndex].amount - collateralsAfter[cIndex].amount, expectedPayout);
    }

    function testSellerCanClearOnlyExpiredOptions() public {
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry + 1 days, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId2, alice, amount);
        engine.execute(address(this), actions);

        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike - 1);

        (, , Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        // covered call, underlying and collateral are the same
        // uint256 uIndex = 0;
        uint256 cIndex = 0;

        // settle marginaccount
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createSettleAction();
        engine.execute(address(this), _actions);

        //margin account should be reset
        (Position[] memory shorts, , Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId2);
        assertEq(shorts[0].amount, amount);
        assertEq(collateralsAfter.length, collateralsBefore.length);
        // assertEq(collateralsAfter[uIndex].collateralId, collateralsBefore[uIndex].collateralId);
        // assertEq(collateralsAfter[uIndex].amount, collateralsBefore[uIndex].amount);
        assertEq(collateralsAfter[cIndex].collateralId, collateralsBefore[cIndex].collateralId);
        assertEq(collateralsAfter[cIndex].amount, collateralsBefore[cIndex].amount);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleCollateralizedPut_FMV2 is FullMarginFixtureV2 {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;
    uint256 private depositAmount = 2000 * 1e6;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        expiry = block.timestamp + 14 days;

        // mint option

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike + 1);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    // settlement on sell side

    function testSellerCanClearOnlyExpiredOptions() public {
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry + 1 days, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId2, alice, amount);
        engine.execute(address(this), actions);

        // expires out the money
        oracle.setExpiryPrice(address(weth), address(usdc), strike + 1);

        (, , Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        uint256 cIndex = 0;

        // settle marginaccount
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createSettleAction();
        engine.execute(address(this), _actions);

        //margin account should be reset
        (Position[] memory shorts, , Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId2);
        assertEq(shorts[0].amount, amount);
        assertEq(collateralsAfter.length, collateralsBefore.length);
        // assertEq(collateralsAfter[uIndex].collateralId, collateralsBefore[uIndex].collateralId);
        // assertEq(collateralsAfter[uIndex].amount, collateralsBefore[uIndex].amount);
        assertEq(collateralsAfter[cIndex].collateralId, collateralsBefore[cIndex].collateralId);
        assertEq(collateralsAfter[cIndex].amount, collateralsBefore[cIndex].amount);
    }

    function testSellerCollateralIsReducedIfExpiresITM() public {
        // expires out the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);

        (, , Balance[] memory collateralsBefore) = engine.marginAccounts(address(this));

        uint256 cIndex = 0;

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        // margin account should be reset
        (Position[] memory shorts, , Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collateralsAfter.length, collateralsBefore.length);
        // assertEq(collateralsAfter[uIndex].collateralId, collateralsBefore[uIndex].collateralId);
        // assertEq(collateralsBefore[uIndex].amount - collateralsAfter[uIndex].amount, expectedPayout);
        assertEq(collateralsAfter[cIndex].collateralId, collateralsBefore[cIndex].collateralId);
        assertEq(collateralsBefore[cIndex].amount - collateralsAfter[cIndex].amount, expectedPayout);
    }
}
