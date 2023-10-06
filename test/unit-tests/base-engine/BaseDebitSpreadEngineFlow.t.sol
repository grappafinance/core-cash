// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {MockedBaseEngineSetup} from "./MockedBaseEngineSetup.sol";
import {stdError} from "forge-std/Test.sol";

import "../../types.sol";

import {TokenType} from "../../../src/config/enums.sol";
import "../../../src/config/constants.sol";
import "../../../src/config/errors.sol";

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
        actions[0] =
            ActionArgs({action: ActionType.AddCollateral, data: abi.encode(address(this), uint80(depositAmount), usdcId)});
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefore - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefore, depositAmount);
    }

    function testCannotAddCollatFromOthers() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.AddCollateral, data: abi.encode(random, uint80(100), usdcId)});

        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testRemoveCollateralMoveBalance() public {
        // prepare
        uint256 depositAmount = 800 * 1e6;
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] =
            ActionArgs({action: ActionType.AddCollateral, data: abi.encode(address(this), uint80(depositAmount), usdcId)});
        engine.execute(address(this), _actions);

        // check before
        uint256 engineBalanceBefore = usdc.balanceOf(address(engine));
        uint256 myBalanceBefore = usdc.balanceOf(address(this));

        // remove collateral
        ActionArgs[] memory actions = new ActionArgs[](1);

        actions[0] =
            ActionArgs({action: ActionType.RemoveCollateral, data: abi.encode(uint80(depositAmount), address(this), usdcId)});
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
        _actions[0] =
            ActionArgs({action: ActionType.AddCollateral, data: abi.encode(address(this), uint80(withdrawAmount), usdcId)});
        engine.execute(address(this), _actions);

        // remove collateral should revert
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] =
            ActionArgs({action: ActionType.RemoveCollateral, data: abi.encode(uint80(withdrawAmount + 1), address(this), usdcId)});
        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testMintActionShouldMintOption() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        ActionArgs[] memory actions = new ActionArgs[](1);

        actions[0] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(this), uint64(amount))});
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testBurnActionShouldBurnOption() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(this), uint64(amount))});
        engine.execute(address(this), _actions);

        // burn
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.BurnShort, data: abi.encode(tokenId, address(this), uint64(amount))});
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnFromOthers() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // burn
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.BurnShort, data: abi.encode(tokenId, random, uint64(amount))});
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testSplitActionShouldMintToken() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        uint256 strikePriceHigher = 5000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 spreadId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, strikePrice, strikePriceHigher);

        uint256 expectedLong = getTokenId(TokenType.CALL, productId, expiry, strikePriceHigher, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.SplitOptionToken, data: abi.encode(spreadId, uint64(amount), address(this))});
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), expectedLong), amount);
    }

    function testMergeActionShouldBurnToken() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);
        uint256 shortId = getTokenId(TokenType.CALL, productId, expiry, strikePrice + 1, 0);

        // prepare: mint 4000 call option to this address
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(this), uint64(amount))});
        engine.execute(address(this), _actions);

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.MergeOptionToken, data: abi.encode(tokenId, shortId, address(this), amount)});
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotMergeWithSameStrike() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.MergeOptionToken, data: abi.encode(tokenId, tokenId, address(this), amount)});
        vm.expectRevert(BM_MergeWithSameStrike.selector);
        engine.execute(address(this), actions);
    }

    function testCannotAddLongFromOthers() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // execute add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.AddLong, data: abi.encode(tokenId, uint64(amount), address(0))});

        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testAddLongShouldMoveToken() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(this), uint64(amount))});
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        // add long into the account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.AddLong, data: abi.encode(tokenId, uint64(amount), address(this))});
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }

    function testRemoveLongShouldPullToken() public {
        uint256 amount = 1 * UNIT;
        uint256 tokenId = _getDefaultCallId();

        // prepare: mint tokens to engine
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(engine), uint64(amount))});
        engine.execute(address(this), _actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);

        // add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.RemoveLong, data: abi.encode(tokenId, uint64(amount), address(this))});
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
        actions[0] = ActionArgs({action: ActionType.SettleAccount, data: ""});

        vm.expectEmit(false, false, false, true, address(engine));
        emit AccountSettledSingle(address(this), usdcId, amount);
        engine.execute(address(this), actions);
    }

    function _getDefaultCallId() internal view returns (uint256 tokenId) {
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);
    }
}
