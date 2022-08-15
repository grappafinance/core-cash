// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../../shared/AdvancedFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract TestMergeOption is AdvancedFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1000 * UNIT;
    uint256 public amount = 1 * UNIT;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(marginEngine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(engineId, address(this), actions);
    }

    function testMergeCallChangeStorage() public {
        // mint new call option for this address

        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, address(this));
        grappa.execute(engineId, address(this), actions);

        // check result
        (uint256 shortCallId, , , , , ) = marginEngine.marginAccounts(address(this));
        (, , , uint64 longStrike, uint64 shortStrike) = parseTokenId(shortCallId);

        assertTrue(shortCallId != newTokenId);
        assertEq(longStrike, strikePrice);
        assertEq(shortStrike, higherStrike);
    }

    function testCanMergeForAccountOwnerFromAuthorizedAccount() public {
        // mint new call option for "this" address
        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        // authorize alice to change subaccount
        grappa.setAccountAccess(alice, true);

        // merge by alice
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, address(this));
        vm.prank(alice);
        grappa.execute(engineId, address(this), actions);

        // check result
        (uint256 shortCallId, , , , , ) = marginEngine.marginAccounts(address(this));
        (, , , uint64 longStrike, uint64 shortStrike) = parseTokenId(shortCallId);

        assertTrue(shortCallId != newTokenId);
        assertEq(longStrike, strikePrice);
        assertEq(shortStrike, higherStrike);
    }

    function testCannotMergeWithTokenFromOthers() public {
        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, address(alice));

        vm.expectRevert(MA_InvalidFromAddress.selector);
        grappa.execute(engineId, address(this), actions);
    }

    function testMergeIntoCreditSpreadCanRemoveCollateral() public {
        // mint new call option for this address
        uint256 higherStrike = 4200 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        uint256 amountToRemove = depositAmount - (higherStrike - strikePrice);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, address(this));
        actions[1] = createRemoveCollateralAction(amountToRemove, usdcId, address(this));
        grappa.execute(engineId, address(this), actions);

        //action should not revert
    }

    function testMergeIntoDebitSpreadCanRemoveAllCollateral() public {
        // mint new call option for this address
        uint256 lowerStrike = 3800 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, lowerStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, address(this));
        actions[1] = createRemoveCollateralAction(depositAmount, usdcId, address(this));
        grappa.execute(engineId, address(this), actions);

        //action should not revert
    }
}
