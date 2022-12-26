// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestPMRemoveCollateral_CM is CrossMarginFixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        weth.mint(alice, 100 * 1e18);

        vm.startPrank(alice);
        weth.approve(address(engine), type(uint256).max);
        usdc.approve(address(engine), type(uint256).max);
        engine.setAccountAccess(address(this), type(uint256).max);
        vm.stopPrank();

        expiry = block.timestamp + 1 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testEqualShortLongAllowCollateralWithdraw() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, strikePrice, 0);

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

        Balance[] memory balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 0);

        uint256 balanceBefore = weth.balanceOf(address(this));

        actions[0] = createRemoveCollateralAction(depositAmount, wethId, address(this));
        engine.execute(address(this), actions);

        balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 0);

        uint256 balanceAfter = weth.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + depositAmount);

        (,, Balance[] memory _collaters) = engine.marginAccounts(address(this));
        assertEq(_collaters.length, 0);
    }

    function testEqualCallSpreadCollateralWithdraw() public {
        uint256 depositAmount = 1 * 1e18;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 strikeSpread = 1 * UNIT;

        uint256 shortId =
            getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, strikePrice - strikeSpread, 0);
        uint256 longId = getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, strikePrice, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        _actions[1] = createMintAction(shortId, alice, amount);
        engine.execute(address(this), _actions);

        _actions[0] = createAddCollateralAction(wethId, alice, depositAmount);
        _actions[1] = createMintAction(longId, address(this), amount);
        engine.execute(alice, _actions);

        option.setApprovalForAll(address(engine), true);

        assertEq(option.balanceOf(address(this), longId), amount);
        assertEq(option.balanceOf(address(alice), shortId), amount);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(longId, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), longId), 0);

        uint256 underlyingRequired = (((strikeSpread * UNIT) / strikePrice) * (10 ** (18 - 6)));

        Balance[] memory balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, underlyingRequired);

        uint256 balanceBefore = weth.balanceOf(address(this));

        actions[0] = createRemoveCollateralAction(depositAmount - uint256(balances[0].amount), wethId, address(this));
        engine.execute(address(this), actions);

        uint256 balanceAfter = weth.balanceOf(address(this));

        uint256 expectedBalance = depositAmount - underlyingRequired;
        assertEq(balanceAfter, balanceBefore + expectedBalance);

        (,, Balance[] memory _collaters) = engine.marginAccounts(address(this));
        assertEq(_collaters.length, 1);
        assertEq(_collaters[0].collateralId, wethId);
        assertEq(_collaters[0].amount, underlyingRequired);
    }

    function testEqualPutSpreadCollateralWithdraw() public {
        uint256 depositAmount = 2000 * 1e6;

        uint256 strikePrice = 2000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 strikeSpread = 1;

        uint256 tokenId = getTokenId(DerivativeType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strikePrice, 0);
        uint256 tokenId2 =
            getTokenId(DerivativeType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, strikePrice - strikeSpread, 0);

        // prepare: mint tokens
        ActionArgs[] memory _actions = new ActionArgs[](2);
        _actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        _actions[1] = createMintAction(tokenId, alice, amount);
        engine.execute(address(this), _actions);

        _actions[0] = createAddCollateralAction(usdcId, alice, depositAmount);
        _actions[1] = createMintAction(tokenId2, address(this), amount);
        engine.execute(alice, _actions);

        option.setApprovalForAll(address(engine), true);

        assertEq(option.balanceOf(address(this), tokenId2), amount);
        assertEq(option.balanceOf(address(alice), tokenId), amount);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddLongAction(tokenId2, amount, address(this));
        engine.execute(address(this), actions);

        assertEq(option.balanceOf(address(this), tokenId2), 0);

        uint256 strikeSpreadScaled = strikeSpread * (10 ** (6 - 6));

        Balance[] memory balances = engine.getMinCollateral(address(this));
        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, strikeSpreadScaled);

        uint256 balanceBefore = usdc.balanceOf(address(this));

        actions[0] = createRemoveCollateralAction(depositAmount - uint256(balances[0].amount), usdcId, address(this));
        engine.execute(address(this), actions);

        uint256 balanceAfter = usdc.balanceOf(address(this));

        uint256 expectedBalance = depositAmount - strikeSpreadScaled;
        assertEq(balanceAfter, balanceBefore + expectedBalance);

        (,, Balance[] memory _collaters) = engine.marginAccounts(address(this));
        assertEq(_collaters.length, 1);
        assertEq(_collaters[0].collateralId, usdcId);
        assertEq(_collaters[0].amount, strikeSpreadScaled);
    }
}
