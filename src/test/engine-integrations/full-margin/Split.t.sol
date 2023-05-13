// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "./FullMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestSplitCallSpread_FM is FullMarginFixture {
    uint256 public expiry;
    uint256 public strikePriceLow = 4000 * UNIT;
    uint256 public strikePriceHigh = 5000 * UNIT;
    uint256 public depositAmount = 0.2 ether;
    uint256 public amount = 1 * UNIT;
    uint256 public spreadId;

    function setUp() public {
        weth.mint(address(this), 100 ether);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 7 days;

        // mint a 4000-5000 debit spread
        spreadId = getTokenId(SettlementType.CASH, TokenType.CALL_SPREAD, pidEthCollat, expiry, strikePriceLow, strikePriceHigh);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(spreadId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function testSplitCallSpread() public {
        // split
        uint256 amountToAdd = 1 ether - depositAmount;
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(wethId, address(this), amountToAdd); // will need to add collateral
        engine.execute(address(this), actions);

        // check result
        (uint256 shortId, uint64 shortAmount,,) = engine.marginAccounts(address(this));
        (, TokenType tokenType,,, uint64 longStrike, uint64 shortStrike) = parseTokenId(shortId);

        assertEq(uint8(tokenType), uint8(TokenType.CALL));
        assertEq(longStrike, strikePriceLow);
        assertEq(shortAmount, amount);
        assertEq(shortStrike, 0);
    }

    function testSplitCallSpreadCreateNewCallToken() public {
        uint256 amountToAdd = 1 ether - depositAmount;
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(wethId, address(this), amountToAdd); // will need to add collateral
        engine.execute(address(this), actions);

        // check result
        uint256 expectedTokenId = getTokenId(SettlementType.CASH, TokenType.CALL, pidEthCollat, expiry, strikePriceHigh, 0);

        assertEq(option.balanceOf(address(this), expectedTokenId), amount);
    }

    function testCannotSplitCallSpreadWithoutAddingCollateral() public {
        // only split
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }
}

// solhint-disable-next-line contract-name-camelcase
contract TestSplitPutSpread_FM is FullMarginFixture {
    uint256 public expiry;
    uint256 public strikePriceHigh = 2000 * UNIT;
    uint256 public strikePriceLow = 1900 * UNIT;
    uint256 public depositAmount = 100 * UNIT;
    uint256 public amount = 1 * UNIT;
    uint256 public spreadId;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 7 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 2000-1900 debit spread
        spreadId = getTokenId(SettlementType.CASH, TokenType.PUT_SPREAD, pidUsdcCollat, expiry, strikePriceHigh, strikePriceLow);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(spreadId, address(this), amount);
        engine.execute(address(this), actions);
    }

    function testSplitPutSpread() public {
        uint256 amountToAdd = strikePriceHigh - depositAmount;
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), amountToAdd); // will need to add collateral
        engine.execute(address(this), actions);

        // check result
        (uint256 shortId,,,) = engine.marginAccounts(address(this));
        (, TokenType tokenType,,, uint64 longStrike, uint64 shortStrike) = parseTokenId(shortId);

        assertEq(uint8(tokenType), uint8(TokenType.PUT));
        assertEq(longStrike, strikePriceHigh);
        assertEq(shortStrike, 0);
    }

    function testSplitCallSpreadCreateNewCallToken() public {
        uint256 amountToAdd = strikePriceHigh - depositAmount;
        // split
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createSplitAction(spreadId, amount, address(this));
        actions[1] = createAddCollateralAction(usdcId, address(this), amountToAdd); // will need to add collateral
        engine.execute(address(this), actions);

        // check result
        uint256 expectedTokenId = getTokenId(SettlementType.CASH, TokenType.PUT, pidUsdcCollat, expiry, strikePriceLow, 0);

        assertEq(option.balanceOf(address(this), expectedTokenId), amount);
    }

    function testCannotSplitCallSpreadWithoutAddingCollateral() public {
        // only split
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount, address(this));

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(address(this), actions);
    }

    function testCannotSplitNonExistingSpreadId() public {
        uint256 fakeLongStrike = strikePriceHigh - (50 * UNIT);
        uint256 fakeSpreadId =
            getTokenId(SettlementType.CASH, TokenType.PUT_SPREAD, pidEthCollat, expiry, fakeLongStrike, strikePriceLow);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(fakeSpreadId, amount, address(this));

        vm.expectRevert(FM_InvalidToken.selector);
        engine.execute(address(this), actions);
    }

    function testCannotSplitWithWrongAmount() public {
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createSplitAction(spreadId, amount / 2, address(this));

        vm.expectRevert(FM_SplitAmountMisMatch.selector);
        engine.execute(address(this), actions);
    }
}
