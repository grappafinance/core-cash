// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {MockedBaseEngineSetup} from "./MockedBaseEngineSetup.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract BaseDebitSpreadEngineFlow is MockedBaseEngineSetup {
    address public random = address(0xaabb);

    event AccountSettledSingle(address subAccount, uint8 collateralId, int256 payout);

    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        engine.setIsAboveWater(true);
    }

    function testExecuteShouldRevertIfUnderWater() public {
        engine.setIsAboveWater(false);

        vm.expectRevert(BM_AccountUnderwater.selector);
        ActionArgs[] memory actions = new ActionArgs[](0);
        engine.execute(address(this), actions);
    }

    function testAddCollateralMoveBalance() public {
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount);
    }

    function testCannotAddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, random, 100);
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testRemoveCollateralMoveBalance() public {
        // prepare
        uint256 depositAmount = 800 * 1e6;
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), _actions);

        // check before
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));

        // remove collateral
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceAfter - myBalanceBefore, depositAmount);
        assertEq(engineBalanceBefore - engineBalanceAfter, depositAmount);
    }

    function testCannotRemoveMoreThanEngineHas() public {
        // prepare
        uint256 withdrawAmount = 800 * 1e6;
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createAddCollateralAction(usdcId, address(this), withdrawAmount);
        engine.execute(address(this), _actions);

        // remove collateral should revert
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(withdrawAmount + 1, usdcId, address(this));
        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testMintActionShouldMintOption() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testBurnActionShouldBurnOption() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), _actions);

        // burn
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnFromOthers() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // burn
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, random, amount);
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testSplitActionShouldMintToken() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        uint256 strikePriceHigher = 5000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 spreadId = getTokenId(SettlementType.CASH, TokenType.CALL_SPREAD, productId, expiry, strikePrice, strikePriceHigher);

        uint256 expectedLong = getTokenId(SettlementType.CASH, TokenType.CALL, productId, expiry, strikePriceHigher, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), expectedLong), amount);
    }

    function testMergeActionShouldBurnToken() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(SettlementType.CASH, TokenType.CALL, productId, expiry, strikePrice, 0);
        uint256 shortId = getTokenId(SettlementType.CASH, TokenType.CALL, productId, expiry, strikePrice + 1, 0);

        // prepare: mint 4000 call option to this address
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), _actions);

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(tokenId, shortId, address(this), amount);
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotMergeWithSameStrike() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(tokenId, tokenId, address(this), amount);
        vm.expectRevert(BM_MergeWithSameStrike.selector);
        engine.execute(address(this), actions);
    }

    function testCannotAddLongFromOthers() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // execute add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(0));

        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testAddLongShouldMoveToken() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        // add long into the account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }

    function testRemoveLongShouldPullToken() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare: mint tokens to engine
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createMintAction(tokenId, address(engine), amount);
        engine.execute(address(this), _actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);

        // add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), amount);
        assertEq(option.balanceOf(address(engine), tokenId), 0);
    }

    function testSettlementShouldEmitEvent() public {
        int80 amount = 100 * 1e6;
        engine.setPayout(amount);
        engine.setPayoutCollatId(usdcId);

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();

        vm.expectEmit(false, false, false, true, address(engine));
        emit AccountSettledSingle(address(this), usdcId, amount);
        engine.execute(address(this), actions);
    }

    function _getDefaultCallId() internal view returns (uint256 tokenId) {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        tokenId = getTokenId(SettlementType.CASH, TokenType.CALL, productId, expiry, strikePrice, 0);
    }
}
