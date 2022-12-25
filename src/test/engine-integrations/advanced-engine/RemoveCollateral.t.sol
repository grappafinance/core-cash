// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {AdvancedFixture} from "./AdvancedFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestRemoveCollateral_AM is AdvancedFixture {
    uint256 private depositAmount = 1000 * 1e6;

    function setUp() public {
        // approve engine
        usdc.mint(address(this), 1000_000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);
    }

    function testRemoveCollateralChangeStorage() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);
        (,,,, uint80 collateralAmount, uint8 collateralId) = engine.marginAccounts(address(this));

        assertEq(collateralId, 0);
        assertEq(collateralAmount, 0);
    }

    function testCannotRemoveDifferentCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, wethId, address(this));

        vm.expectRevert(AM_WrongCollateralId.selector);
        engine.execute(address(this), actions);
    }

    function testCannotRemoveMoreThanOwn() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount + 1, usdcId, address(this));

        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testCanRemoveExtraCollateralBeforeSettlement() public {
        // add short into the vault
        uint256 expiry = block.timestamp + 2 hours;
        uint256 strikeHigher = 1200 * UNIT;
        uint256 strikeLower = 1000 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.PUT_SPREAD, SettlementType.CASH, productId, expiry, strikeHigher, strikeLower);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), UNIT);

        // mint option: create short position
        engine.execute(address(this), actions);

        // test remove collateral
        uint256 collateralNeeded = (200 * UNIT);
        uint256 amountToRemove = depositAmount - collateralNeeded;

        ActionArgs[] memory actions2 = new ActionArgs[](1);
        actions2[0] = createRemoveCollateralAction(amountToRemove, usdcId, address(this));

        // remove collateral
        engine.execute(address(this), actions2);

        (,,,, uint80 collateralAmount,) = engine.marginAccounts(address(this));
        assertEq(collateralAmount, collateralNeeded);
    }

    function testCannotRemoveCollateralBeforeSettleExpiredShort() public {
        // add short into the vault
        uint256 expiry = block.timestamp + 2 hours;
        uint256 strike = 2500 * UNIT;
        uint256 strikeHigher = 3000 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.CALL_SPREAD, SettlementType.CASH, productId, expiry, strike, strikeHigher);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), UNIT);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);

        // expires in the money
        uint256 expiryPrice = 2800 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        ActionArgs[] memory actions2 = new ActionArgs[](1);
        actions2[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));

        vm.expectRevert(AM_ExpiredShortInAccount.selector);
        engine.execute(address(this), actions2);
    }
}
