// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

contract FullMarginEngineGenernalV2 is FullMarginFixtureV2 {
    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);
    }

    function testCannotCallAddLongWithNotAuthorizedEngine() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(0, 0, address(this));

        vm.expectRevert(FM_Not_Authorized_Engine.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallRemoveLongNotInAccount() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createRemoveLongAction(0, 0, address(this));

        vm.expectRevert(FM_InvalidToken.selector);
        engine.execute(address(this), actions);
    }

    function testCannotCallPayoutFromAnybody() public {
        vm.expectRevert(NoAccess.selector);
        engine.payCashValue(address(usdc), address(this), UNIT);
    }

    function testGetMinCollateral() public {
        uint256 expiry = block.timestamp + 1 days;
        uint256 depositAmount = 3000 * 1e6;

        uint256 strikePrice = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        engine.execute(address(this), actions);

        SBalance[] memory balances = engine.getMinCollateral(address(this));

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, int256(depositAmount));
    }
}
