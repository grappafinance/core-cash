// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";

import {L1MarginMathLib} from "src/core/L1/libraries/L1MarginMathLib.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";
import "src/config/types.sol";

contract L1MarginMathLibTest is Test {
    uint256 public constant base = UNIT;
    uint256 public today;

    function setUp() public {
        today = block.timestamp;
    }

    function testMinCollateralOTMCall() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = L1MarginMathLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat, 796950000); // 786 USD

        // spot decrease, min collateral also decrease
        spot = 2500 * base;
        uint256 minCollat2 = L1MarginMathLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat2, 664125000); // 664 USD
    }

    function testMinCollateralITMCall() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = L1MarginMathLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat, 1574500000); // 1574 USD

        // spot increase, min collateral also increase
        spot = 4000 * base;
        uint256 minCollat2 = L1MarginMathLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat2, 2124500000); // 664 USD
    }

    function testMinCollateralOTMPut() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = L1MarginMathLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat, 724500000); // 724.5 USD

        // increasing spot price, the min collateral stay the same
        spot = 4000 * base;
        uint256 minCollat2 = L1MarginMathLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            getDefaultConfig()
        );
        assertEq(minCollat2, 724500000); // 724.5 USD
    }

    function testMinCollateralITMPut() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;

        ProductMarginParameter memory config = getDefaultConfig();

        uint256 minCollat = L1MarginMathLib.getMinCollateralForShortPut(amount, strike, expiry, spot, config);
        assertEq(minCollat, 1452050000); // 1452 USD

        // decrease spot price, the min collateral increase
        spot = 2000 * base;
        uint256 minCollat2 = L1MarginMathLib.getMinCollateralForShortPut(amount, strike, expiry, spot, config);
        assertEq(minCollat2, 2134700000); // 2134 USD

        // capped at strike price
        spot = 0;
        uint256 minCollat3 = L1MarginMathLib.getMinCollateralForShortPut(amount, strike, expiry, spot, config);
        assertEq(minCollat3, 3500000000); // 3500 USD
    }

    function testTimeDecayValueLowerBond() public {
        uint256 expiry = today + 8000 seconds;
        ProductMarginParameter memory config = getDefaultConfig();
        uint256 decay = L1MarginMathLib.getTimeDecay(expiry, config);
        assertEq(decay, config.discountRatioLowerBound);
    }

    function testTimeDecayValueUpperBond() public {
        uint256 expiry = today + 180 days + 10 seconds;
        ProductMarginParameter memory config = getDefaultConfig();
        uint256 decay = L1MarginMathLib.getTimeDecay(expiry, config);
        assertEq(decay, config.discountRatioUpperBound);
    }

    function testTimeDecayValue90Days() public {
        uint256 expiry = today + 90 days;
        uint256 decay = L1MarginMathLib.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 4626); // 46.26
    }

    function testTimeDecayValue30Days() public {
        uint256 expiry = today + 30 days;
        uint256 decay = L1MarginMathLib.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 2818); // 28%
    }

    function testCallCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = L1MarginMathLib.getCallCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot < strike
        spot = 2800 * base;
        cash = L1MarginMathLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);

        // spot = strike
        spot = 2900 * base;
        cash = L1MarginMathLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testPutCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = L1MarginMathLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);

        // spot < strike
        spot = 2800 * base;
        cash = L1MarginMathLib.getPutCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot = strike
        spot = 2900 * base;
        cash = L1MarginMathLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function getDefaultConfig() internal pure returns (ProductMarginParameter memory config) {
        return
            ProductMarginParameter({
                discountPeriodUpperBound: 180 days,
                discountPeriodLowerBound: 1 days,
                sqrtMaxDiscountPeriod: 3944, // (86400*180).sqrt()
                sqrtMinDiscountPeriod: 293, // 86400.sqrt()
                discountRatioUpperBound: 6400, // 64%
                discountRatioLowerBound: 800, // 8%
                shockRatio: 1000 // 10%
            });
    }
}
