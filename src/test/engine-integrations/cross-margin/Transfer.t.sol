// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestTransfer_CM is CrossMarginFixture {
    uint256 public expiry;
    uint256 public c4000;
    uint256 public c5000;
    uint256 public depositAmount = 1 * 1e18;
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

        c4000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 4000 * UNIT, 0);

        c5000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 5000 * UNIT, 0);

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        ActionArgs[] memory aliceActions = new ActionArgs[](2);
        aliceActions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        aliceActions[1] = createMintIntoAccountAction(c5000, address(this), amount);

        ActionArgs[] memory selfActions = new ActionArgs[](2);
        selfActions[0] = createAddCollateralAction(wethId, address(this), depositAmount / 5);
        selfActions[1] = createMintAction(c4000, bob, amount);

        BatchExecute[] memory batch = new BatchExecute[](2);
        batch[0] = BatchExecute(alice, aliceActions);
        batch[1] = BatchExecute(address(this), selfActions);

        engine.batchExecute(batch);
    }

    function testTransferCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](3);
        actions[0] = createTransferCollateralAction(depositAmount / 5, wethId, alice);
        actions[1] = createTranferLongAction(c5000, alice, amount);
        actions[2] = createTranferShortAction(c4000, alice, amount);
        engine.execute(address(this), actions);

        (Position[] memory aliceShorts, Position[] memory aliceLongs, Balance[] memory aliceCollaterals) =
            engine.marginAccounts(alice);

        assertEq(aliceCollaterals.length, 1);
        assertEq(aliceCollaterals[0].collateralId, wethId);
        assertEq(aliceCollaterals[0].amount, depositAmount + (depositAmount / 5));

        assertEq(aliceLongs.length, 1);
        assertEq(aliceLongs[0].tokenId, c5000);
        assertEq(aliceLongs[0].amount, amount);

        assertEq(aliceShorts.length, 2);
        assertEq(aliceShorts[0].tokenId, c5000);
        assertEq(aliceShorts[0].amount, amount);
        assertEq(aliceShorts[1].tokenId, c4000);
        assertEq(aliceShorts[1].amount, amount);

        (Position[] memory selfShorts, Position[] memory selfLongs, Balance[] memory selfCollaterals) =
            engine.marginAccounts(address(this));

        assertEq(selfCollaterals.length, 0);
        assertEq(selfShorts.length, 0);
        assertEq(selfLongs.length, 0);
    }

    function testCannotTransferCollateralWhenShortExists() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createTransferCollateralAction(depositAmount / 5, wethId, alice);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotTransferLongWhenTooLittleCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createTranferLongAction(c5000, bob, amount);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotTransferShortWhenReceiverHasTooLittleCollateral() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createTranferShortAction(c4000, alice, amount);

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotTransferShortWithNoAccess() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createTranferShortAction(c4000, bob, amount);

        vm.expectRevert(NoAccess.selector);
        engine.execute(address(this), actions);
    }
}
