// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";

import "../../../test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSettleOptionPartialMargin_CM is CrossMarginFixture {
    MockERC20 internal lsEth;
    MockERC20 internal sdyc;

    uint8 internal lsEthId;
    uint8 internal sdycId;

    uint40 internal pidLsEthCollat;
    uint40 internal pidSdycCollat;

    uint256 public expiry;

    function setUp() public {
        lsEth = new MockERC20("LsETH", "LsETH", 18);
        vm.label(address(lsEth), "LsETH");

        sdyc = new MockERC20("SDYC", "SDYC", 6);
        vm.label(address(sdyc), "SDYC");

        lsEthId = grappa.registerAsset(address(lsEth));
        sdycId = grappa.registerAsset(address(sdyc));

        engine.setPartialMarginMask(address(weth), address(lsEth), true);
        engine.setPartialMarginMask(address(usdc), address(sdyc), true);

        pidLsEthCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(lsEth));
        pidSdycCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(sdyc));

        lsEth.mint(address(this), 100 * 1e18);
        lsEth.approve(address(engine), type(uint256).max);

        sdyc.mint(address(this), 1000_000 * 1e6);
        sdyc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
        oracle.setSpotPrice(address(lsEth), 3000 * UNIT);

        oracle.setSpotPrice(address(sdyc), 1 * UNIT);
    }

    function testCallITM() public {
        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 1 * 1e18;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);

        uint256 wethExpiryPrice = 5000 * UNIT;
        uint256 lsEthExpiryPrice = 5200 * UNIT; // staked eth worth more due to rewards

        oracle.setExpiryPrice(address(weth), address(usdc), wethExpiryPrice);
        oracle.setExpiryPrice(address(lsEth), address(usdc), lsEthExpiryPrice);

        vm.warp(expiry);

        uint256 lsEthBefore = lsEth.balanceOf(alice);
        uint256 expectedPayout = (wethExpiryPrice - strikePrice) * UNIT / lsEthExpiryPrice * (depositAmount / UNIT);

        grappa.settleOption(alice, tokenId, amount);

        uint256 lsEthAfter = lsEth.balanceOf(alice);
        assertEq(lsEthAfter, lsEthBefore + expectedPayout);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));
        assertEq(collateralsAfter.length, 1);
        assertEq(collateralsAfter[0].amount, depositAmount - expectedPayout);
    }

    function testPutITM() public {
        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 depositAmount = 2000 * 1e6;

        uint256 tokenId = getTokenId(TokenType.PUT, pidSdycCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(sdycId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);

        uint256 wethExpiryPrice = 1000 * UNIT;
        uint256 sdycExpiryPrice = 1_040000; // worth more due to interest ($1.04)

        oracle.setExpiryPrice(address(weth), address(usdc), wethExpiryPrice);
        oracle.setExpiryPrice(address(sdyc), address(usdc), sdycExpiryPrice);

        vm.warp(expiry);

        uint256 sdycBefore = sdyc.balanceOf(alice);
        uint256 expectedPayout = (strikePrice - wethExpiryPrice) * UNIT / sdycExpiryPrice;

        grappa.settleOption(alice, tokenId, amount);

        uint256 sdycAfter = sdyc.balanceOf(alice);
        assertEq(sdycAfter, sdycBefore + expectedPayout);

        actions = new ActionArgs[](1);
        actions[0] = createSettleAction();
        engine.execute(address(this), actions);

        (,, Balance[] memory collateralsAfter) = engine.marginAccounts(address(this));
        assertEq(collateralsAfter.length, 1);
        assertEq(collateralsAfter[0].amount, depositAmount - expectedPayout);
    }
}
