// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestBurnOption_CM is CrossMarginFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1 ether;
    uint256 public amount = 1 * UNIT;
    uint256 public tokenId;

    function setUp() public {
        weth.mint(address(this), depositAmount);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        tokenId = getTokenId(SettlementType.CASH, TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function testBurn() public {
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        engine.execute(address(this), actions);
        (Position[] memory shorts,,) = engine.marginAccounts(address(this));

        // check result
        assertEq(shorts.length, 0);

        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnWithWrongTokenId() public {
        address subAccount = address(uint160(address(this)) - 1);

        // badId: usdc Id
        uint256 badTokenId = getTokenId(SettlementType.CASH, TokenType.CALL, pidUsdcCollat, expiry, strikePrice, 0);
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(badTokenId, address(this), amount);

        // action
        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(subAccount, actions); // execute on subaccount
    }

    function testCannotBurnForEmptyAccount() public {
        address subAccount = address(uint160(address(this)) - 1);

        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(subAccount, actions); // execute on subaccount
    }

    function testCannotBurnWhenOptionTokenBalanceIsLow() public {
        // prepare: transfer some optionToken out
        option.safeTransferFrom(address(this), alice, tokenId, 1, "");

        // build burn arg
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // expect
        vm.expectRevert(stdError.arithmeticError);
        engine.execute(address(this), actions);
    }

    function testCannotBurnFromUnAuthorizedAccount() public {
        // send option to alice
        option.safeTransferFrom(address(this), alice, tokenId, amount, "");

        // build burn arg: try building with alice's options
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, alice, amount);

        // expect error
        vm.expectRevert(BM_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }
}
