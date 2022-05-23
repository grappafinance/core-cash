// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";
import {ActionHelper} from "src/test/shared/ActionHelper.sol";

import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountConstants.sol";
import "src/constants/MarginAccountEnums.sol";
import "src/constants/TokenEnums.sol";

import "forge-std/console2.sol";

contract TestMintVanillaOption is Fixture, ActionHelper {
    // mocked
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);
    }

    function testMintVanilaCallChangeStorage() public {
        uint256 depositAmount = 10000 * 1e6;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
        (uint256 shortCallId, uint256 shortPutId, uint64 shortCallAmount, uint64 shortPutAmount, , ) = grappa
            .marginAccounts(address(this));

        assertEq(shortCallId, tokenId);
        assertEq(shortPutId, 0);
        assertEq(shortCallAmount, amount);
        assertEq(shortPutAmount, 0);
    }

    function testMintVanilaCallSpread() public {
        uint256 longStrike = 3000 * UNIT;
        uint256 shortStrike = 3200 * UNIT;

        uint256 depositAmount = shortStrike - longStrike;

        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, longStrike, shortStrike);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
        
        (uint256 shortCallId, uint256 shortPutId, uint64 shortCallAmount, uint64 shortPutAmount, , ) = grappa
            .marginAccounts(address(this));

        assertEq(shortCallId, tokenId);
        assertEq(shortPutId, 0);
        assertEq(shortCallAmount, amount);
        assertEq(shortPutAmount, 0);
    }

    function testMintVanilaPutChangeStorage() public {
        uint256 depositAmount = 10000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
        (uint256 shortCallId, uint256 shortPutId, uint64 shortCallAmount, uint64 shortPutAmount, , ) = grappa
            .marginAccounts(address(this));

        assertEq(shortCallId, 0);
        assertEq(shortPutId, tokenId);
        assertEq(shortCallAmount, 0);
        assertEq(shortPutAmount, amount);
    }

    function testMintPutSpreadChangeStorage() public {
        uint256 longStrike = 2800 * UNIT;
        uint256 shortStrike = 2600 * UNIT;

        uint256 depositAmount = longStrike - shortStrike;

        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT_SPREAD, productId, expiry, longStrike, shortStrike);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(productId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
        
        (, uint256 shortPutId,, uint64 shortPutAmount, , ) = grappa.marginAccounts(address(this));

        assertEq(shortPutId, tokenId);
        assertEq(shortPutAmount, amount);
    }

    function testCannotMintWithoutCollateral() public {
        uint256 strikePrice = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        // actions[0] = createAddCollateralAction(address(usdc), address(this), depositAmount);
        actions[0] = createMintAction(tokenId, address(this), amount);

        vm.expectRevert(AccountUnderwater.selector);
        grappa.execute(address(this), actions);
    }
}
