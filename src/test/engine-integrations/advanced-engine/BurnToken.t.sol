// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../../shared/AdvancedFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract TestBurnCall is AdvancedFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1000 * UNIT;
    uint256 public amount = 1 * UNIT;
    uint256 public tokenId;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function testBurn() public {
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        engine.execute(address(this), actions);
        (uint256 shortCallId, , uint64 shortCallAmount, , , ) = engine.marginAccounts(address(this));

        // check result
        assertEq(shortCallId, 0);
        assertEq(shortCallAmount, 0);
        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnForEmptyAdvancedMarginEngine() public {
        address subAccount = address(uint160(address(this)) - 1);

        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        vm.expectRevert(AM_InvalidToken.selector);
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
        vm.expectRevert(GP_InvalidFromAddress.selector);
        engine.execute(address(this), actions);
    }

    function testCanRemoveCollateralAfterBurn() public {
        uint256 collateralBefore = usdc.balanceOf(address(this));

        // build args: burn and remove collateral
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createBurnAction(tokenId, address(this), amount);
        actions[1] = createRemoveCollateralAction(amount, usdcId, address(this));

        // exeucte
        engine.execute(address(this), actions);

        uint256 collateralAfter = usdc.balanceOf(address(this));
        assertEq(collateralAfter, collateralBefore + amount);
    }
}
