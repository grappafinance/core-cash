// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";

import {AdvancedMarginMath} from "../../../core/engines/advanced-margin/AdvancedMarginMath.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * Test if the formula is working properly for min collateral calculation:
 * Desmos file with same parameter can be found here: 
            https://www.desmos.com/calculator/mx6le8msfo
 */
contract AdvancedMarginMathTest is Test {
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
        uint256 vol = UNIT;

        uint256 minCollat = AdvancedMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat, 405771429); // 405 USD

        // spot decrease, min collateral also decrease
        spot = 2500 * base;
        uint256 minCollat2 = AdvancedMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat2, 281785715); // 281 USD
    }

    function testMinCollateralITMCall() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = AdvancedMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat, 973400000); // 1224 USD

        // spot increase, min collateral also increase
        spot = 4000 * base;
        uint256 minCollat2 = AdvancedMarginMath.getMinCollateralForShortCall(
            amount,
            strike,
            expiry,
            spot,
            UNIT,
            getDefaultConfig()
        );
        assertEq(minCollat2, 1473400000); // 1473.5 USD
    }

    function testMinCollateralOTMPut() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        uint256 minCollat = AdvancedMarginMath.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat, 405771429); // ~406 USD

        // increasing spot price, the min collateral stay the same
        spot = 4000 * base;
        uint256 minCollat2 = AdvancedMarginMath.getMinCollateralForShortPut(
            amount,
            strike,
            expiry,
            spot,
            vol,
            getDefaultConfig()
        );
        assertEq(minCollat2, 355050000); // 355 USD
    }

    function testMinCollateralITMPut() public {
        uint256 spot = 3000 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        ProductMarginParams memory config = getDefaultConfig();

        uint256 minCollat = AdvancedMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat, 973400000); // 973 USD

        // decrease spot price, the min collateral increase
        spot = 2000 * base;
        uint256 minCollat2 = AdvancedMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat2, 1815600000); // 1815 USD

        // capped at strike price
        spot = 0;
        uint256 minCollat3 = AdvancedMarginMath.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat3, 3500000000); // 3500 USD
    }

    function testTimeDecayValueLowerBond() public {
        uint256 expiry = today + 8000 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = AdvancedMarginMath.getTimeDecay(expiry, config);
        assertEq(decay, config.rLower);
    }

    function testTimeDecayValueUpperBond() public {
        uint256 expiry = today + 180 days + 10 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = AdvancedMarginMath.getTimeDecay(expiry, config);
        assertEq(decay, config.rUpper);
    }

    function testTimeDecayValue90Days() public {
        uint256 expiry = today + 90 days;
        uint256 decay = AdvancedMarginMath.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 2645); // 26.45%
    }

    function testTimeDecayValue30Days() public {
        uint256 expiry = today + 30 days;
        uint256 decay = AdvancedMarginMath.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 1773); // 17.73%
    }

    function getDefaultConfig() internal pure returns (ProductMarginParams memory config) {
        return
            ProductMarginParams({
                dUpper: 180 days,
                dLower: 1 days,
                sqrtDUpper: 3944, // (86400*180).sqrt()
                sqrtDLower: 293, // 86400.sqrt()
                rUpper: 3500, // 35%
                rLower: 800, // 8%
                volMultiplier: 10000 // 100%
            });
    }
}
