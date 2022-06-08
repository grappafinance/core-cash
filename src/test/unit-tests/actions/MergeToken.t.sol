// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

contract TestMergeOption is Fixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1000 * UNIT;
    uint256 public amount = 1 * UNIT;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint a 3000 strike call first
        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
    }

    function testMergeCallChangeStorage() public {
        // mint new call option for this address

        uint256 higherStrike = 5000 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        // merge
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createMergeAction(newTokenId, address(this));
        grappa.execute(address(this), actions);
        (uint256 shortCallId, , , , , ) = grappa.marginAccounts(address(this));

        // check result
        (, , , uint64 longStrike, uint64 shortStrike) = parseTokenId(shortCallId);

        assertTrue(shortCallId != newTokenId);
        assertEq(longStrike, strikePrice);
        assertEq(shortStrike, higherStrike);
    }

    function testMergeIntoCreditSpreadCanRemoveCollateral() public {
        // mint new call option for this address
        uint256 higherStrike = 4200 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        uint256 amountToRemove = depositAmount - (higherStrike - strikePrice);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, address(this));
        actions[1] = createRemoveCollateralAction(amountToRemove, address(this));
        grappa.execute(address(this), actions);

        //action should not revert
    }

    function testMergeIntoDebitSpreadCanRemoveAllCollateral() public {
        // mint new call option for this address
        uint256 lowerStrike = 3800 * UNIT;
        uint256 newTokenId = getTokenId(TokenType.CALL, productId, expiry, lowerStrike, 0);
        mintOptionFor(address(this), newTokenId, productId, amount);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createMergeAction(newTokenId, address(this));
        actions[1] = createRemoveCollateralAction(depositAmount, address(this));
        grappa.execute(address(this), actions);

        //action should not revert
    }
}
