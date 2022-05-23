// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";
import {ActionHelper} from "src/test/shared/ActionHelper.sol";

import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountConstants.sol";
import "src/constants/MarginAccountEnums.sol";
import "src/constants/TokenEnums.sol";

import "forge-std/console2.sol";

contract TestSettleCall is Fixture, ActionHelper {
    // mocked
    uint256 public expiry;

    // unit
    uint64 amount = uint64(1 * UNIT);

    uint256 tokenId;

    uint64 strike;

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
        // give optoin to alice.
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
        uint256 optionBefore = grappa.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = grappa.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires out the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(expiryPrice) - strike);

        vm.startPrank(alice);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = grappa.balanceOf(alice, tokenId);

        grappa.settleOption(tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = grappa.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);

        vm.stopPrank();
    }
}
