// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../../shared/AdvancedFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

contract TestSplitCallSpread is AdvancedFixture {
    uint256 public expiry;
    uint256 public strikePriceLow = 4000 * UNIT;
    uint256 public strikePriceHigh = 4100 * UNIT;
    uint256 public depositAmount = 100 * UNIT;
    uint256 public amount = 1 * UNIT;
    uint256 public spreadId;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(amEngine), type(uint256).max);

        expiry = block.timestamp + 7 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 4000-4100 debit spread
        spreadId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, strikePriceLow, strikePriceHigh);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(spreadId, address(this), amount);
        grappa.execute(amEngineId, address(this), actions);
    }

    function testSplitCallSpread() public {
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount * 5); // will need to add collateral
        grappa.execute(amEngineId, address(this), actions);

        // check result
        (uint256 shortCallId, , , , , ) = amEngine.marginAccounts(address(this));
        (TokenType tokenType, , , uint64 longStrike, uint64 shortStrike) = parseTokenId(shortCallId);

        assertEq(uint8(tokenType), uint8(TokenType.CALL));
        assertEq(longStrike, strikePriceLow);
        assertEq(shortStrike, 0);
    }

    function testSplitCallSpreadCreateNewCallToken() public {
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount * 5); // will need to add collateral
        grappa.execute(amEngineId, address(this), actions);

        // check result
        uint256 expectedTokenId = getTokenId(TokenType.CALL, productId, expiry, strikePriceHigh, 0);

        assertEq(option.balanceOf(address(this), expectedTokenId), amount);
    }

    function testCannotSplitCallSpreadWithoutAddingCollateral() public {
        // only split
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));

        vm.expectRevert(GP_AccountUnderwater.selector);
        grappa.execute(amEngineId, address(this), actions);
    }
}

contract TestSplitPutSpread is AdvancedFixture {
    uint256 public expiry;
    uint256 public strikePriceHigh = 2000 * UNIT;
    uint256 public strikePriceLow = 1900 * UNIT;
    uint256 public depositAmount = 100 * UNIT;
    uint256 public amount = 1 * UNIT;
    uint256 public spreadId;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(amEngine), type(uint256).max);

        expiry = block.timestamp + 7 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 2000-1900 debit spread
        spreadId = getTokenId(TokenType.PUT_SPREAD, productId, expiry, strikePriceHigh, strikePriceLow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(spreadId, address(this), amount);
        grappa.execute(amEngineId, address(this), actions);
    }

    function testSplitPutSpread() public {
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount * 5); // will need to add collateral
        grappa.execute(amEngineId, address(this), actions);

        // check result
        (, uint256 shortPutId, , , , ) = amEngine.marginAccounts(address(this));
        (TokenType tokenType, , , uint64 longStrike, uint64 shortStrike) = parseTokenId(shortPutId);

        assertEq(uint8(tokenType), uint8(TokenType.PUT));
        assertEq(longStrike, strikePriceHigh);
        assertEq(shortStrike, 0);
    }

    function testSplitCallSpreadCreateNewCallToken() public {
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), depositAmount * 5); // will need to add collateral
        grappa.execute(amEngineId, address(this), actions);

        // check result
        uint256 expectedTokenId = getTokenId(TokenType.PUT, productId, expiry, strikePriceLow, 0);

        assertEq(option.balanceOf(address(this), expectedTokenId), amount);
    }

    function testCannotSplitCallSpreadWithoutAddingCollateral() public {
        // only split
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));

        vm.expectRevert(GP_AccountUnderwater.selector);
        grappa.execute(amEngineId, address(this), actions);
    }

    function testCannotSplitNonExistingSpreadId() public {
        uint256 fakeLongStrike = strikePriceHigh - (50 * UNIT);
        uint256 fakeSpreadId = getTokenId(TokenType.PUT_SPREAD, productId, expiry, fakeLongStrike, strikePriceLow);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(fakeSpreadId, amount, address(this));

        vm.expectRevert(AM_InvalidToken.selector);
        grappa.execute(amEngineId, address(this), actions);
    }

    function testCannotSplitWithWrongAmount() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount / 2, address(this));

        vm.expectRevert(AM_SplitAmountMisMatch.selector);
        grappa.execute(amEngineId, address(this), actions);
    }
}
