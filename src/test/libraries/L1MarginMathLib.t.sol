// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";

import {SimpleMarginMath} from "src/core/SimpleMargin/libraries/SimpleMarginMath.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";
import "src/config/types.sol";

contract SimpleMarginMathTest is Test {
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

        uint256 minCollat = SimpleMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat, 796950000); // 786 USD

        // spot decrease, min collateral also decrease
        spot = 2500 * base;
        uint256 minCollat2 = SimpleMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat2, 664125000); // 664 USD
    }

    function testMinCollateralITMCall() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = SimpleMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat, 1574500000); // 1574 USD

        // spot increase, min collateral also increase
        spot = 4000 * base;
        uint256 minCollat2 = SimpleMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat2, 2124500000); // 2124.5 USD
    }

    function testMinCollateralOTMPut() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        uint256 minCollat = SimpleMarginMath.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat, 621000001); // 621 USD

        // increasing spot price, the min collateral stay the same
        spot = 4000 * base;
        uint256 minCollat2 = SimpleMarginMath.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat2, 543375000); // 543.5 USD
    }

    function testMinCollateralITMPut() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        ProductMarginParams memory config = getDefaultConfig();

        uint256 minCollat = SimpleMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat, 1224500000); // 1121 USD

        // decrease spot price, the min collateral increase
        spot = 2000 * base;
        uint256 minCollat2 = SimpleMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat2, 1983000000); // 1983,6 USD

        // capped at strike price
        spot = 0;
        uint256 minCollat3 = SimpleMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat3, 3500000000); // 3500 USD
    }

    function testTimeDecayValueLowerBond() public {
        uint256 expiry = today + 8000 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = SimpleMarginMath.getTimeDecay(expiry, config);
        assertEq(decay, config.discountRatioLowerBound);
    }

    function testTimeDecayValueUpperBond() public {
        uint256 expiry = today + 180 days + 10 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = SimpleMarginMath.getTimeDecay(expiry, config);
        assertEq(decay, config.discountRatioUpperBound);
    }

    function testTimeDecayValue90Days() public {
        uint256 expiry = today + 90 days;
        uint256 decay = SimpleMarginMath.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 4626); // 46.26
    }

    function testTimeDecayValue30Days() public {
        uint256 expiry = today + 30 days;
        uint256 decay = SimpleMarginMath.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 2818); // 28%
    }

    function testCallCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = SimpleMarginMath.getCallCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot < strike
        spot = 2800 * base;
        cash = SimpleMarginMath.getCallCashValue(spot, strike);
        assertEq(cash, 0);

        // spot = strike
        spot = 2900 * base;
        cash = SimpleMarginMath.getCallCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testPutCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = SimpleMarginMath.getPutCashValue(spot, strike);
        assertEq(cash, 0);

        // spot < strike
        spot = 2800 * base;
        cash = SimpleMarginMath.getPutCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot = strike
        spot = 2900 * base;
        cash = SimpleMarginMath.getPutCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function getDefaultConfig() internal pure returns (ProductMarginParams memory config) {
        return
            ProductMarginParams({
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
