// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../utils/Console.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestPortfolioMargining_FMV2 is FullMarginFixtureV2 {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(alice, 100 * 1e18);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        engine.setAccountAccess(address(this), true);
        vm.stopPrank();

        expiry = block.timestamp + 1 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testEqualShortLongAllowCollateralWithdraw() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        _actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), _actions);

        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(alice, _actions);

        option.setApprovalForAll(address(engine), true);

        assertEq(option.balanceOf(address(this), tokenId), amount);
        assertEq(option.balanceOf(address(alice), tokenId), amount);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId), 0);

        SBalance[] memory balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(uint80(balances[0].amount), depositAmount);

        uint256 balanceBefore = weth.balanceOf(address(this));

        actions[0] = createRemoveCollateralAction(depositAmount, wethId, address(this));
        engine.execute(address(this), actions);

        balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 0);

        uint256 balanceAfter = weth.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + depositAmount);
    }
}
