// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

contract CrossEngineGenernal is CrossMarginFixture {
    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);
    }

    function testCannotCallAddLongWithExpiredOption() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(0, 0, address(this));

        vm.expectRevert(CM_Option_Expired.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallAddLongWithNotAuthorizedEngine() public {
        uint40 productId = grappa.getProductId(address(oracle), address(0), address(weth), address(usdc), address(usdc));

        uint256 tokenId = getTokenId(SettlementType.CASH, TokenType.CALL, productId, block.timestamp + 1 days, 0, 0);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId, 0, address(this));

        vm.expectRevert(CM_Not_Authorized_Engine.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallRemoveLongNotInAccount() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveLongAction(0, 0, address(this));

        vm.expectRevert(CM_InvalidToken.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallPayoutFromAnybody() public {
        vm.expectRevert(NoAccess.selector);
        engine.payCashValue(address(usdc), address(this), UNIT);
    }

    function testGetMinCollateral() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 depositAmount = 5000 * 1e6;

        uint256 strikePrice = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(SettlementType.CASH, TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        engine.execute(address(this), actions);

        Balance[] memory balances = engine.getMinCollateral(address(this));

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, strikePrice);
    }
}
