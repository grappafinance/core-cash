// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../utils/Console.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestPMSettleLongs_FMV2 is FullMarginFixtureV2 {
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
        engine.setAccountAccess(address(this), true);
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

    function testSettleLongITMIncreasesCollateral() public {
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

    function testSettleLongOTMIncreasesCollateral() public {
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
}
