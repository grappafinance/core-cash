// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";
import {MarginAccountLib} from "../../libraries/MarginAccountLib.sol";

// import constants
import "../../constants/MarginAccountConstants.sol";

contract MarginAccountLibTest is Test {
    uint256 public constant base = UNIT;
    uint256 public today;

    function setUp() public {
        today = block.timestamp;
    }

    function testMinCollateralOTMCall() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 shock = 1000; // 10%
        uint256 expiry = today + 21 days;

        uint256 minCollat = MarginAccountLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat, 796950000); // 786 USD

        // spot decrease, min collateral also decrease
        spot = 2500 * base;
        uint256 minCollat2 = MarginAccountLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat2, 664125000); // 664 USD
    }

    function testMinCollateralITMCall() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 shock = 1000; // 10%
        uint256 expiry = today + 21 days;

        uint256 minCollat = MarginAccountLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat, 1574500000); // 1574 USD

        // spot increase, min collateral also increase
        spot = 4000 * base;
        uint256 minCollat2 = MarginAccountLib.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat2, 2124500000); // 664 USD
    }

    function testMinCollateralOTMPut() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 shock = 1000; // 10%
        uint256 expiry = today + 21 days;

        uint256 minCollat = MarginAccountLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat, 724500000); // 724.5 USD

        // increasing spot price, the min collateral stay the same
        spot = 4000 * base;
        uint256 minCollat2 = MarginAccountLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat2, 724500000); // 724.5 USD
    }

    function testMinCollateralITMPut() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 shock = 1000; // 10%
        uint256 expiry = today + 21 days;

        uint256 minCollat = MarginAccountLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat, 1452050000); // 1452 USD

        // decrease spot price, the min collateral increase
        spot = 2000 * base;
        uint256 minCollat2 = MarginAccountLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat2, 2134700000); // 2134 USD

        // capped at strike price
        spot = 0;
        uint256 minCollat3 = MarginAccountLib.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            shock
        );
        assertEq(minCollat3, 3500000000); // 3500 USD
    }

    function testTimeDecayValueLowerBond() public {
        uint256 expiry = today + 8000 seconds;
        uint256 decay = MarginAccountLib.getTimeDecay(expiry);
        assertEq(decay, DISCOUNT_RATIO_LOWER_BOUND);
    }

    function testTimeDecayValueUpperBond() public {
        uint256 expiry = today + 180 days + 10 seconds;
        uint256 decay = MarginAccountLib.getTimeDecay(expiry);
        assertEq(decay, DISCOUNT_RATIO_UPPER_BOUND);
    }

    function testTimeDecayValue90Days() public {
        uint256 expiry = today + 90 days;
        uint256 decay = MarginAccountLib.getTimeDecay(expiry);
        assertEq(decay, 4626); // 46.26
    }

    function testTimeDecayValue30Days() public {
        uint256 expiry = today + 30 days;
        uint256 decay = MarginAccountLib.getTimeDecay(expiry);
        assertEq(decay, 2818); // 28%
    }

    function testCallCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = MarginAccountLib.getCallCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot < strike
        spot = 2800 * base;
        cash = MarginAccountLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);

        // spot = strike
        spot = 2900 * base;
        cash = MarginAccountLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testPutCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = MarginAccountLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);

        // spot < strike
        spot = 2800 * base;
        cash = MarginAccountLib.getPutCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot = strike
        spot = 2900 * base;
        cash = MarginAccountLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);
    }
}
