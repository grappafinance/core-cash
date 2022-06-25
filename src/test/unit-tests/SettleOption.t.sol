// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

import "forge-std/console2.sol";

contract TestSettleCall is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike - 1);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(expiryPrice) - strike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestSettleCoveredCall is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1 * 1e18;

        strike = uint64(4000 * UNIT);

        tokenId = getTokenId(TokenType.CALL, productIdEthCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike - 1);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = ((uint64(expiryPrice) - strike) / 5000) * (10**(18 - UNIT_DECIMALS));
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);
        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestSettlePut is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, productId, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike + 1);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = strike - uint64(expiryPrice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestSettleETHCollateralizedPut is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private strike;

    function setUp() public {
        weth.mint(address(this), 1000 * 1e18);
        weth.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1 * 1e18;

        strike = uint64(2000 * UNIT);

        tokenId = getTokenId(TokenType.PUT, productIdEthCollat, expiry, strike, 0);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strike + 1);
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(wethBefore, wethAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutIfExpiresIMT() public {
        // expires in the money
        uint256 expiryPrice = 1600 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = ((strike - uint64(expiryPrice)) / 1600) * (10**(18 - UNIT_DECIMALS));
        uint256 wethBefore = weth.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 wethAfter = weth.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);
        assertEq(wethAfter, wethBefore + expectedPayout);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestSettleCallSpread is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(4000 * UNIT);
        shortStrike = uint64(4200 * UNIT);

        tokenId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutDifferenceBetweenSpotAndLongStrike() public {
        // expires in the money, not higher than upper bond
        uint256 expiryPrice = 4100 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(expiryPrice) - longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testPayoutShouldBeCappedAtShortStrike() public {
        // expires in the money, higher than upper bond
        uint256 expiryPrice = 5000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = (uint64(shortStrike) - longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestSettlePutSpread is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256 private tokenId;
    uint64 private longStrike;
    uint64 private shortStrike;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        longStrike = uint64(2000 * UNIT);
        shortStrike = uint64(1800 * UNIT);

        tokenId = getTokenId(TokenType.PUT_SPREAD, productId, expiry, longStrike, shortStrike);
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        // give optoin to alice
        actions[1] = createMintAction(tokenId, alice, amount);

        // mint option
        grappa.execute(address(this), actions);

        // expire option
        vm.warp(expiry);
    }

    function testShouldGetNothingIfExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(longStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testShouldGetPayoutDifferenceBetweenSpotAndLongStrike() public {
        // expires in the money, not lower than lower bond
        uint256 expiryPrice = 1900 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = longStrike - uint64(expiryPrice);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }

    function testPayoutShouldBeCappedAtShortStrike() public {
        // expires in the money, lower than lower bond
        uint256 expiryPrice = 1000 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedPayout = longStrike - uint64(shortStrike);
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 optionBefore = option.balanceOf(alice, tokenId);

        grappa.settleOption(alice, tokenId, amount);

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 optionAfter = option.balanceOf(alice, tokenId);

        assertEq(usdcBefore + expectedPayout, usdcAfter);
        assertEq(optionBefore, optionAfter + amount);
    }
}

contract TestBatchSettleCall is Fixture {
    uint256 public expiry;

    uint64 private amount = uint64(1 * UNIT);
    uint256[] private tokenIds = new uint256[](3);
    uint256[] private amounts = new uint256[](3);
    uint64[] private strikes = new uint64[](3);

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(3000 * UNIT);

        // mint option
        uint256 depositAmount = 1000 * 1e6;

        strikes[0] = uint64(3500 * UNIT);
        strikes[1] = uint64(4000 * UNIT);
        strikes[2] = uint64(4500 * UNIT);

        tokenIds[0] = getTokenId(TokenType.CALL, productId, expiry, strikes[0], 0);
        tokenIds[1] = getTokenId(TokenType.CALL, productId, expiry, strikes[1], 0);
        tokenIds[2] = getTokenId(TokenType.CALL, productId, expiry, strikes[2], 0);

        // mint 2 tokens to alice
        for (uint160 i = 0; i < 3; i++) {
            amounts[i] = amount;

            ActionArgs[] memory actions = new ActionArgs[](2);
            actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
            // give optoin to alice
            actions[1] = createMintAction(tokenIds[i], alice, amount);
            // mint option
            grappa.execute(address(uint160(address(this)) + i), actions);
        }
        // expire option
        vm.warp(expiry);
    }

    function testCannotSettleWithWrongCollateral() public {
        oracle.setExpiryPrice(strikes[0] - 1);

        vm.expectRevert(WrongSettlementCollateral.selector);
        grappa.batchSettleOptions(alice, tokenIds, amounts, address(weth));
    }

    function testShouldGetNothingIfAllOptionsExpiresOTM() public {
        // expires out the money
        oracle.setExpiryPrice(strikes[0] - 1);

        uint256 usdcBefore = usdc.balanceOf(alice);

        grappa.batchSettleOptions(alice, tokenIds, amounts, address(usdc));

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 option1After = option.balanceOf(alice, tokenIds[0]);
        uint256 option2After = option.balanceOf(alice, tokenIds[1]);
        uint256 option3After = option.balanceOf(alice, tokenIds[2]);

        assertEq(usdcBefore, usdcAfter);
        assertEq(option1After, 0);
        assertEq(option2After, 0);
        assertEq(option3After, 0);
    }

    function testShouldGetPayoutIfOneOptionExpiresITM() public {
        // strikes[1] and strikes[2] expries OTM
        // only get 500 out of strikes[0]
        oracle.setExpiryPrice(strikes[1]);

        uint256 expectedReturn = strikes[1] - strikes[0];

        uint256 usdcBefore = usdc.balanceOf(alice);
        grappa.batchSettleOptions(alice, tokenIds, amounts, address(usdc));

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 option1After = option.balanceOf(alice, tokenIds[0]);
        uint256 option2After = option.balanceOf(alice, tokenIds[1]);
        uint256 option3After = option.balanceOf(alice, tokenIds[2]);

        assertEq(usdcBefore + expectedReturn, usdcAfter);
        assertEq(option1After, 0);
        assertEq(option2After, 0);
        assertEq(option3After, 0);
    }

    function testShouldGetPayoutIfAllOptionsExpiresITM() public {
        // strikes[1] and strikes[2] expries OTM
        // only get 500 out of strikes[0]
        uint256 expiryPrice = strikes[2] + 500 * UNIT;
        oracle.setExpiryPrice(expiryPrice);

        uint256 expectedReturn = 3 * expiryPrice - (strikes[0] + strikes[1] + strikes[2]);

        uint256 usdcBefore = usdc.balanceOf(alice);
        grappa.batchSettleOptions(alice, tokenIds, amounts, address(usdc));

        uint256 usdcAfter = usdc.balanceOf(alice);
        uint256 option1After = option.balanceOf(alice, tokenIds[0]);
        uint256 option2After = option.balanceOf(alice, tokenIds[1]);
        uint256 option3After = option.balanceOf(alice, tokenIds[2]);

        assertEq(usdcBefore + expectedReturn, usdcAfter);
        assertEq(option1After, 0);
        assertEq(option2After, 0);
        assertEq(option3After, 0);
    }
}
