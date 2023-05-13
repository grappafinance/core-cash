// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

contract Permissioned is CrossMarginFixture {
    uint256 public expiry;
    uint256 public tokenId;
    uint256 public amount;
    uint256 public depositAmount;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        engine.setWhitelist(address(whitelist));

        depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;

        amount = 1 * UNIT;

        expiry = block.timestamp + 14 days;

        tokenId = getTokenId(SettlementType.CASH, TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testCannotExecute() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        vm.expectRevert(NoAccess.selector);
        engine.execute(address(this), actions);
    }

    function testCanExecute() public {
        whitelist.setEngineAccess(address(this), true);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(wethId, address(this), 1000 * UNIT);

        engine.execute(address(this), actions);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));
        assertEq(collaterals.length, 1);
    }

    function testCannotSettleOption() public {
        whitelist.setEngineAccess(address(this), true);

        _mintOptionToAlice();

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        vm.warp(expiry);

        vm.startPrank(alice);
        vm.expectRevert(NoAccess.selector);
        grappa.settleOption(alice, tokenId, amount);
    }

    function testAliceCanSettleOption() public {
        whitelist.setEngineAccess(address(this), true);
        whitelist.setEngineAccess(alice, true);

        _mintOptionToAlice();

        oracle.setExpiryPrice(address(weth), address(usdc), 5000 * UNIT);

        vm.warp(expiry);

        vm.startPrank(alice);
        grappa.settleOption(alice, tokenId, amount);
        vm.stopPrank();
    }

    function _mintOptionToAlice() public {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), actions);
    }
}
