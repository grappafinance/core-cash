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
contract TestMintWithPartialMarginBeta_CM is CrossMarginFixture {
    MockERC20 internal lsEth;
    MockERC20 internal mmc;
    MockERC20 internal usdt;
    uint8 internal lsEthId;
    uint8 internal mmcId;
    uint8 internal usdtId;

    // usdc strike & mmc collateralized  call / put
    uint40 internal pidMmcCollat;
    uint40 internal pidUsdtMmcCollat;

    // eth strike & lsEth collateralized call / put
    uint40 internal pidLsEthCollat;

    uint256 public expiry;

    function setUp() public {
        lsEth = new MockERC20("LsETH", "LsETH", 18);
        vm.label(address(lsEth), "LsETH");

        mmc = new MockERC20("MMC", "MMC", 6);
        vm.label(address(mmc), "MMC");

        usdt = new MockERC20("USDT", "USDT", 6);
        vm.label(address(usdt), "USDT");

        mmcId = grappa.registerAsset(address(mmc));
        lsEthId = grappa.registerAsset(address(lsEth));
        usdtId = grappa.registerAsset(address(usdt));

        engine.setMarginMask(address(weth), address(lsEth), true);
        engine.setMarginMask(address(lsEth), address(weth), true);
        engine.setMarginMask(address(usdc), address(mmc), true);
        engine.setMarginMask(address(usdc), address(usdt), true);
        engine.setMarginMask(address(usdt), address(mmc), true);

        pidMmcCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(mmc));
        pidUsdtMmcCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdt), address(mmc));
        pidLsEthCollat = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(lsEth));

        mmc.mint(address(this), 1000_000 * 1e6);
        mmc.approve(address(engine), type(uint256).max);

        usdt.mint(address(this), 1000_000 * 1e6);
        usdt.approve(address(engine), type(uint256).max);

        lsEth.mint(address(this), 100 * 1e18);
        lsEth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testMintCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintCallWithSimilarCollateral() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.CALL, pidLsEthCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createAddCollateralAction(lsEthId, address(this), depositAmount * 2);
        actions[1] = createMintAction(tokenId1, address(this), amount);
        actions[2] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0].tokenId, tokenId1);
        assertEq(shorts[0].amount, amount);
        assertEq(shorts[1].tokenId, tokenId2);
        assertEq(shorts[1].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId1), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
    }

    function testMintPut() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidMmcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(mmcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintPutWithSimilarCollateral() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidMmcCollat, expiry, strikePrice, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createAddCollateralAction(mmcId, address(this), depositAmount * 2);
        actions[1] = createMintAction(tokenId1, address(this), amount);
        actions[2] = createMintAction(tokenId2, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0].tokenId, tokenId1);
        assertEq(shorts[0].amount, amount);
        assertEq(shorts[1].tokenId, tokenId2);
        assertEq(shorts[1].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId1), amount);
        assertEq(option.balanceOf(address(this), tokenId2), amount);
    }

    function testCannotMintTooLittleCollateral() public {
        uint256 amount = 1 * UNIT;

        uint256 tokenId1 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);
        uint256 tokenId2 = getTokenId(TokenType.PUT, pidUsdtMmcCollat, expiry, 2000 * UNIT, 0);
        uint256 tokenId3 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 3000 * UNIT, 0);

        ActionArgs[] memory actions = new ActionArgs[](6);
        actions[0] = createAddCollateralAction(usdtId, address(this), 900 * 1e6);
        actions[1] = createAddCollateralAction(mmcId, address(this), 1200 * 1e6);
        actions[2] = createAddCollateralAction(lsEthId, address(this), 1 * 1e18);
        actions[3] = createMintAction(tokenId1, address(this), amount);
        actions[4] = createMintAction(tokenId2, address(this), amount);
        actions[5] = createMintAction(tokenId3, address(this), amount);

        vm.expectRevert(BM_AccountUnderwater.selector);

        engine.execute(address(this), actions);

        actions[0] = createAddCollateralAction(usdtId, address(this), 1800 * 1e6);
        engine.execute(address(this), actions);

        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 3);
    }
}
