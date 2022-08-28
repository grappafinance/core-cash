// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {FullMarginFixture} from "../../shared/FullMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMintCall_FM is FullMarginFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(fmEngine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(fmEngine), type(uint256).max);

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
        grappa.execute(fmEngineId, address(this), actions);
        (uint256 shortId, uint64 shortAmount, , ) = fmEngine.marginAccounts(address(this));

        assertEq(shortId, tokenId);
        assertEq(shortAmount, amount);
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
        grappa.execute(fmEngineId, address(this), actions);
    }

    function testCannotMintCoveredCallUsingUsdcCollateral() public {
        uint256 depositAmount = 1000 * UNIT;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        // specify we want to mint with eth collateral
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);

        // actually deposit usdc!
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(FM_CollateraliMisMatch.selector);
        grappa.execute(fmEngineId, address(this), actions);

        ActionArgs[] memory actions2 = new ActionArgs[](2);

        // reverse the 2 actions
        actions2[0] = createMintAction(tokenId, address(this), amount);
        actions2[1] = createAddCollateralAction(usdcId, address(this), depositAmount);

        vm.expectRevert(FM_WrongCollateralId.selector);
        grappa.execute(fmEngineId, address(this), actions2);
    }

    function testMintPut() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(fmEngineId, address(this), actions);
        (uint256 shortId, uint64 shortAmount, , ) = fmEngine.marginAccounts(address(this));

        assertEq(shortId, tokenId);
        assertEq(shortAmount, amount);
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
        grappa.execute(fmEngineId, address(this), actions);
    }

    function testMintPutSpread() public {
        uint256 longStrike = 2800 * UNIT;
        uint256 shortStrike = 2600 * UNIT;

        uint256 depositAmount = longStrike - shortStrike;

        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT_SPREAD, pidUsdcCollat, expiry, longStrike, shortStrike);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(fmEngineId, address(this), actions);

        (uint256 shortId, uint64 shortAmount, , ) = fmEngine.marginAccounts(address(this));

        assertEq(shortId, tokenId);
        assertEq(shortAmount, amount);
    }
}
