// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestRemoveCollateral_FM is FullMarginFixture {
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
        (,, uint8 _collateralId, uint80 _collateralAmount) = engine.marginAccounts(address(this));

        assertEq(_collateralId, 0);
        assertEq(_collateralAmount, 0);
    }

    function testRemoveCollateralMoveBalance() public {
        uint256 engineBalanceBefoe = usdc.balanceOf(address(engine));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceAfter - myBalanceBefoe, depositAmount);
        assertEq(engineBalanceBefoe - engineBalanceAfter, depositAmount);
    }

    function testCannotRemoveDifferentCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, wethId, address(this));

        vm.expectRevert(FM_WrongCollateralId.selector);
        engine.execute(address(this), actions);
    }

    function testCannotRemoveMoreThanOwn() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount + 1, usdcId, address(this));

        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testCannotRemoveCollateralBeforeSettleExpiredShort() public {
        // add short into the vault
        uint256 expiry = block.timestamp + 2 hours;
        uint256 strike = 2500 * UNIT;
        uint256 strikeHigher = 3000 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.CALL_SPREAD, SettlementType.CASH, pidUsdcCollat, expiry, strike, strikeHigher);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), UNIT);

        // mint option
        engine.execute(address(this), actions);

        // expire option
        vm.warp(expiry);

        // expires in the money
        uint256 expiryPrice = 2800 * UNIT;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // remove all collateral and settle
        ActionArgs[] memory actions2 = new ActionArgs[](2);
        actions2[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        actions2[1] = createSettleAction();

        // if user is trying to remove collateral before settlement
        // the tx will revert because the vault has insufficient collateral to cover payout
        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions2);
    }

    function testCannotRemoveMoreCollateralThanPayoutAfterExpiry() public {
        // add short into the vault
        uint256 expiry = block.timestamp + 2 hours;
        uint256 strike = 2500 * UNIT;
        uint256 strikeHigher = 3000 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.CALL_SPREAD, SettlementType.CASH, pidUsdcCollat, expiry, strike, strikeHigher);

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

        // if user remove more collateral than needed to reserve for payout, reverts
        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions2);
    }
}
