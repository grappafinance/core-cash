// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMint_FMV2 is FullMarginFixtureV2 {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testMintCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        (uint256[] memory shorts, uint64[] memory shortAmounts, , , , ) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0], tokenId);
        assertEq(shortAmounts.length, 1);
        assertEq(shortAmounts[0], amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testCannotMintCallWithUsdcCollateral() public {
        uint256 depositAmount = 1000 * UNIT;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(FM_CannotMintOptionWithThisCollateral.selector);
        engine.execute(address(this), actions);
    }

    // since we allow collaterals per account, i dont believe this is applicable anymore.
    // function testCannotMintCoveredCallUsingUsdcCollateral() public {
    //     uint256 depositAmount = 1000 * UNIT;

    //     uint256 strikePrice = 4000 * UNIT;
    //     uint256 amount = 1 * UNIT;

    //     // specify we want to mint with eth collateral
    //     uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

    //     ActionArgs[] memory actions = new ActionArgs[](2);

    //     // actually deposit usdc!
    //     actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
    //     actions[1] = createMintAction(tokenId, address(this), amount);

    //     vm.expectRevert(FM_CollateraliMisMatch.selector);
    //     engine.execute(address(this), actions);

    //     ActionArgs[] memory actions2 = new ActionArgs[](2);

    //     // reverse the 2 actions
    //     actions2[0] = createMintAction(tokenId, address(this), amount);
    //     actions2[1] = createAddCollateralAction(usdcId, address(this), depositAmount);

    //     vm.expectRevert(FM_WrongCollateralId.selector);
    //     engine.execute(address(this), actions2);
    // }

    function testMintPut() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        (uint256[] memory shorts, uint64[] memory shortAmounts, , , , ) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0], tokenId);
        assertEq(shortAmounts.length, 1);
        assertEq(shortAmounts[0], amount);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintCallAndPutInSameAccount() public {
        uint256 callDepositAmount = 1 * 1e18;

        uint256 callStrikePrice = 4000 * UNIT;
        uint256 callAmount = 1 * UNIT;

        uint256 callTokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, callStrikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](4);
        actions[0] = createAddCollateralAction(wethId, address(this), callDepositAmount);
        actions[1] = createMintAction(callTokenId, address(this), callAmount);

        uint256 putDepositAmount = 2000 * 1e6;

        uint256 putStrikePrice = 2000 * UNIT;
        uint256 putAmount = 1 * UNIT;

        uint256 putTokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, putStrikePrice, 0);

        actions[2] = createAddCollateralAction(usdcId, address(this), putDepositAmount);
        actions[3] = createMintAction(putTokenId, address(this), putAmount);

        engine.execute(address(this), actions);
        (
            uint256[] memory shorts,
            uint64[] memory shortAmounts,
            ,
            ,
            uint8[] memory collaterals,
            uint80[] memory collateralAmounts
        ) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 2);
        assertEq(shorts[0], callTokenId);
        assertEq(shorts[1], putTokenId);
        assertEq(shortAmounts.length, 2);
        assertEq(shortAmounts[0], callAmount);
        assertEq(shortAmounts[1], putAmount);
        assertEq(collaterals.length, 2);
        assertEq(collaterals[0], wethId);
        assertEq(collaterals[1], usdcId);
        assertEq(collateralAmounts.length, 2);
        assertEq(collateralAmounts[0], callDepositAmount);
        assertEq(collateralAmounts[1], putDepositAmount);

        assertEq(option.balanceOf(address(this), callTokenId), callAmount);
        assertEq(option.balanceOf(address(this), putTokenId), putAmount);
    }

    function testCannotMintExpiredOption() public {
        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, block.timestamp, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(OT_InvalidExpiry.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintPutWithETHCollateral() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(FM_CannotMintOptionWithThisCollateral.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintCallSpread() public {
        uint256 longStrike = 2800 * UNIT;
        uint256 shortStrike = 2600 * UNIT;

        uint256 depositAmount = longStrike - shortStrike;

        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL_SPREAD, pidUsdcCollat, expiry, longStrike, shortStrike);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(FM_UnsupportedTokenType.selector);
        engine.execute(address(this), actions);
    }

    function testCannotMintPutSpread() public {
        uint256 longStrike = 2800 * UNIT;
        uint256 shortStrike = 2600 * UNIT;

        uint256 depositAmount = longStrike - shortStrike;

        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT_SPREAD, pidUsdcCollat, expiry, longStrike, shortStrike);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(FM_UnsupportedTokenType.selector);
        engine.execute(address(this), actions);
    }
}
