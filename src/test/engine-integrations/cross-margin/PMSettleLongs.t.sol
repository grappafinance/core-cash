// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../utils/Console.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestPMSettleLongCallsCM is CrossMarginFixture {
    uint256 public expiry;
    uint256 public tokenId;
    uint256 public depositAmount = 1 * 1e18;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public amount = 1 * UNIT;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(alice, 100 * 1e18);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        expiry = block.timestamp + 1 days;

        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        oracle.setSpotPrice(address(weth), 2000 * UNIT);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(alice, _actions);

        option.setApprovalForAll(address(engine), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        vm.warp(expiry);
    }

    function testSettleLongCallITMIncreasesCollateral() public {
        oracle.setExpiryPrice(address(weth), address(usdc), 8000 * UNIT);

        uint256 balanceBefore = weth.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 1);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 1);
        assertEq(afterCollaters[0].collateralId, wethId);
        assertEq(afterCollaters[0].amount, depositAmount / 2);
    }

    function testSettleMultipleLongCallsITMIncreasesCollateral() public {
        vm.warp(expiry - 1 days);

        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry - 1 hours, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintIntoAccountAction(tokenId2, address(this), amount);
        engine.execute(alice, _actions);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 8000 * UNIT);

        uint256 balanceBefore = weth.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 2);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 1);
        assertEq(afterCollaters[0].collateralId, wethId);
        assertEq(afterCollaters[0].amount, depositAmount);
    }

    function testSettleLongCallOTMNoIncreaseInCollateral() public {
        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        uint256 balanceBefore = weth.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 1);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 0);
    }

    function testSettleMultipleLongCallsOTMNoIncreaseInCollateral() public {
        vm.warp(expiry - 1 days);

        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice + (1 * UNIT), 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintIntoAccountAction(tokenId2, address(this), amount);
        engine.execute(alice, _actions);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        uint256 balanceBefore = weth.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 2);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 0);
    }

    function testSettleOnlyExpiredLongCallOTMNoIncreaseInCollateral() public {
        vm.warp(expiry - 1 days);

        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry + 1 weeks, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintIntoAccountAction(tokenId2, address(this), amount);
        engine.execute(alice, _actions);

        vm.warp(expiry);

        oracle.setExpiryPrice(address(weth), address(usdc), 3000 * UNIT);

        uint256 balanceBefore = weth.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 2);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 1);
        assertEq(afterLongs[0].tokenId, tokenId2);
        assertEq(afterLongs[0].amount, amount);
        assertEq(afterCollaters.length, 0);
    }
}

contract TestPMSettleLongPutsCM is CrossMarginFixture {
    uint256 public expiry;
    uint256 public tokenId;
    uint256 public depositAmount = 2000 * 1e6;
    uint256 public strikePrice = 2000 * UNIT;
    uint256 public amount = 1 * UNIT;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(alice, 100 * 1e18);

        vm.startPrank(alice);
        usdc.approve(address(engine), type(uint256).max);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        expiry = block.timestamp + 1 days;

        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        oracle.setSpotPrice(address(weth), 4000 * UNIT);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(usdcId, alice, depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(alice, _actions);

        option.setApprovalForAll(address(engine), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        vm.warp(expiry);
    }

    function testSettleLongCallITMIncreasesCollateral() public {
        oracle.setExpiryPrice(address(weth), address(usdc), 1000 * UNIT);

        uint256 balanceBefore = usdc.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 1);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = usdc.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 1);
        assertEq(afterCollaters[0].collateralId, usdcId);
        assertEq(afterCollaters[0].amount, depositAmount / 2);
    }

    function testSettleLongCallOTMNoIncreaseInCollateral() public {
        oracle.setExpiryPrice(address(weth), address(usdc), 4000 * UNIT);

        uint256 balanceBefore = usdc.balanceOf(address(engine));

        (, Position[] memory beforeLongs, Balance[] memory beforeCollaters) = engine.marginAccounts(address(this));

        assertEq(beforeLongs.length, 1);
        assertEq(beforeCollaters.length, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        uint256 balanceAfter = usdc.balanceOf(address(engine));

        assertEq(balanceAfter, balanceBefore);

        (, Position[] memory afterLongs, Balance[] memory afterCollaters) = engine.marginAccounts(address(this));

        assertEq(afterLongs.length, 0);
        assertEq(afterCollaters.length, 0);
    }
}
