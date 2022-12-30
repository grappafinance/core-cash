// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {BaseEngineSetup} from "./BaseEngineSetup.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract BaseEngineFlow is BaseEngineSetup {
    address public random = address(0xaabb);

    event AccountSettled(address subAccount, Balance[] debts, Balance[] payouts);

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
        uint256 engineBalanceBefoe = usdc.balanceOf(address(engine));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));
        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceBefoe - myBalanceAfter, depositAmount);
        assertEq(engineBalanceAfter - engineBalanceBefoe, depositAmount);
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
        uint256 engineBalanceBefoe = usdc.balanceOf(address(engine));
        uint256 myBalanceBefoe = usdc.balanceOf(address(this));

        // remove collateral
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        engine.execute(address(this), actions);

        uint256 engineBalanceAfter = usdc.balanceOf(address(engine));
        uint256 myBalanceAfter = usdc.balanceOf(address(this));

        assertEq(myBalanceAfter - myBalanceBefoe, depositAmount);
        assertEq(engineBalanceBefoe - engineBalanceAfter, depositAmount);
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
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), amount);
    }

    function testMintIntoAccountActionShouldMintOptionIntoAccount() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMintIntoAccountAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }

    function testBurnActionShouldBurnOption() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

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
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

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

        uint256 spreadId =
            getTokenId(TokenType.CALL_SPREAD, SettlementType.CASH, productId, expiry, strikePrice, strikePriceHigher);

        uint256 expecetedLong = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePriceHigher, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), expecetedLong), amount);
    }

    function testMergeActionShouldBurnToken() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);
        uint256 shortId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice + 1, 0);

        // prepare: mint tokens
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
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(tokenId, tokenId, address(this), amount);
        vm.expectRevert(DS_MergeWithSameStrike.selector);
        engine.execute(address(this), actions);
    }

    function testCannotAddLongFromOthers() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

        // execute add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(0));

        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testAddLongShouldMoveToken() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](1);
        _actions[0] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), _actions);

        option.setApprovalForAll(address(engine), true);

        // add long
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }

    function testRemoveLongShouldPullToken() public {
        uint256 expiry = block.timestamp + 1 days;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;
        uint256 tokenId = getTokenId(TokenType.CALL, SettlementType.CASH, productId, expiry, strikePrice, 0);

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
        uint80 amount = 100 * 1e6;
        engine.setPayout(amount);
        engine.setPayoutCollatId(usdcId);

        // execute merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSettleAction();

        Balance[] memory balances = new Balance[](1);
        balances[0] = Balance(usdcId, amount);

        vm.expectEmit(false, false, false, true, address(engine));
        emit AccountSettled(address(this), new Balance[](0), balances);
        engine.execute(address(this), actions);
    }
}
