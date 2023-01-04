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
contract TestSettleCashAndPhysicalLongPositions_CM is CrossMarginFixture {
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
        uint256 physicalToken = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        _mintTokens(physicalToken, wethId, wethDepositAmount);
        _mintTokens(cashToken, wethId, wethDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount / 5);
    }

    function testHolderCanClearLongCallDebtAfterExpiryBeforeWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        _mintTokens(physicalToken, wethId, wethDepositAmount);
        _mintTokens(cashToken, wethId, wethDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), usdcDepositAmount);
        actions[1] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        Position[] memory longs;
        Balance[] memory collaterals;

        (, longs, collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, cashToken);
        assertEq(longs[0].amount, amount);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (, longs, collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, wethDepositAmount + (wethDepositAmount / 5));
    }

    function testHolderCannotClearLongPutAfterWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(physicalToken, usdcId, usdcDepositAmount);
        _mintTokens(cashToken, usdcId, usdcDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (, Position[] memory longs, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount / 4);
    }

    function testHolderCanClearPutDebtAfterWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(physicalToken, usdcId, usdcDepositAmount);
        _mintTokens(cashToken, usdcId, usdcDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), wethDepositAmount);
        actions[1] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        Position[] memory longs;
        Balance[] memory collaterals;

        (, longs, collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, cashToken);
        assertEq(longs[0].amount, amount);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount);

        vm.warp(expiry + engine.settlementWindow());

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (, longs, collaterals) = engine.marginAccounts(address(this));

        assertEq(longs.length, 0);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, usdcDepositAmount + (usdcDepositAmount / 4));
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
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSettleCashAndPhysicalShortPositions_CM is CrossMarginFixture {
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
        uint256 physicalToken = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        _mintTokens(physicalToken, wethId, wethDepositAmount);
        _mintTokens(cashToken, wethId, wethDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, physicalToken);
        assertEq(shorts[0].amount, amount);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, (wethDepositAmount * 2) - (wethDepositAmount / 5));
    }

    function testSellerCanClearCallDebtAfterWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.CALL, SettlementType.CASH, pidEthCollat, expiry, strike, 0);

        _mintTokens(physicalToken, wethId, wethDepositAmount);
        _mintTokens(cashToken, wethId, wethDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        Position[] memory shorts;
        Balance[] memory collaterals;

        (shorts,, collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, physicalToken);
        assertEq(shorts[0].amount, amount);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, (wethDepositAmount * 2) - (wethDepositAmount / 5));

        vm.startPrank(alice);
        usdc.mint(alice, 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        grappa.settle(alice, physicalToken, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + engine.settlementWindow());

        // settle marginaccount
        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (shorts,, collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collaterals.length, 2);
        assertEq(collaterals[0].collateralId, wethId);
        assertEq(collaterals[0].amount, (wethDepositAmount * 2) - (wethDepositAmount / 5) - (wethDepositAmount / 2));
        assertEq(collaterals[1].collateralId, usdcId);
        assertEq(collaterals[1].amount, usdcDepositAmount / 2);
    }

    function testSellerCannotClearPutDebtAfterExpiryBeforeWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(physicalToken, usdcId, usdcDepositAmount);
        _mintTokens(cashToken, usdcId, usdcDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        // settle marginaccount
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should not be reset
        (Position[] memory shorts,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, physicalToken);
        assertEq(shorts[0].amount, amount);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, (usdcDepositAmount * 2) - (usdcDepositAmount / 4));
    }

    function testSellerCanClearPutDebtAfterWindowClosed() public {
        uint256 physicalToken = getTokenId(TokenType.PUT, SettlementType.PHYSICAL, pidUsdcCollat, expiry, strike, 0);
        uint256 cashToken = getTokenId(TokenType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strike, 0);

        _mintTokens(physicalToken, usdcId, usdcDepositAmount);
        _mintTokens(cashToken, usdcId, usdcDepositAmount);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        Position[] memory shorts;
        Balance[] memory collaterals;

        (shorts,, collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, physicalToken);
        assertEq(shorts[0].amount, amount);
        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, (usdcDepositAmount * 2) - (usdcDepositAmount / 4));

        vm.startPrank(alice);
        weth.mint(alice, 1000 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        grappa.settle(alice, physicalToken, amount / 2);
        vm.stopPrank();

        vm.warp(expiry + engine.settlementWindow());

        // settle marginaccount
        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        //margin account should be reset
        (shorts,, collaterals) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 0);
        assertEq(collaterals.length, 2);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, (usdcDepositAmount * 2) - (usdcDepositAmount / 4) - (usdcDepositAmount / 2));
        assertEq(collaterals[1].collateralId, wethId);
        assertEq(collaterals[1].amount, wethDepositAmount / 2);
    }

    function _mintTokens(uint256 tokenId, uint8 collateralId, uint256 depositAmount) internal {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(collateralId, address(this), depositAmount);
        // give option to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        engine.execute(address(this), actions);
    }
}
