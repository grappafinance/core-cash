// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";

import "../../../test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMintIntoAccount_CM is CrossMarginFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testMintIntoAccountCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts, Position[] memory longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);
        assertEq(longs[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }

    function testMintPhysicallySettledIntoAccountCall() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint16 issuerId = engine.registerIssuer(address(this));

        uint256 tokenId = getTokenId(DerivativeType.CALL, SettlementType.PHYSICAL, pidEthCollat, expiry, strikePrice, issuerId);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintIntoAccountAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);

        (Position[] memory shorts, Position[] memory longs,) = engine.marginAccounts(address(this));

        assertEq(shorts.length, 1);
        assertEq(shorts[0].tokenId, tokenId);
        assertEq(shorts[0].amount, amount);

        assertEq(longs.length, 1);
        assertEq(longs[0].tokenId, tokenId);
        assertEq(longs[0].amount, amount);

        assertEq(option.balanceOf(address(this), tokenId), 0);
        assertEq(option.balanceOf(address(engine), tokenId), amount);
    }
}
