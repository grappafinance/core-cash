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

contract MintVanillaOption is Fixture, ActionHelper {
    // mocked
    uint32 public productId = 1;
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;
    }

    function testMintChangeStorage() public {
        uint256 depositAmount = 10000 * 1e6;

        uint256 strikePrice = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, productId, expiry, 0, strikePrice);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(address(usdc), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(address(this), actions);
        (uint256 shortCallId, uint256 shortPutId, uint80 shortCallAmount, uint80 shortPutAmount,,) = grappa
            .marginAccounts(address(this));

        assertEq(shortCallId, tokenId);
        assertEq(shortPutId, 0);
        assertEq(shortCallAmount, amount);
        assertEq(shortPutAmount, 0);
    }
}
