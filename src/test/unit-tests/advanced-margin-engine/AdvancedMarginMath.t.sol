// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {AdvancedMarginMath} from "../../../core/engines/advanced-margin/AdvancedMarginMath.sol";
import "../../../core/engines/advanced-margin/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * @dev forge coverage only pick up coverage for internal libraries
 *      when it's initiated with external calls
 */
contract AdvancedMarginMathTester {
    ///@dev call getMinCollateral and return
    function getMinCollateral(
        AdvancedMarginDetail memory _account,
        ProductDetails memory _assets,
        uint256 _spotUnderlyingStrike,
        uint256 _spotCollateralStrike,
        uint256 _vol,
        ProductMarginParams memory _param
    ) external view returns (uint256) {
        uint256 result =
            AdvancedMarginMath.getMinCollateral(_account, _assets, _spotUnderlyingStrike, _spotCollateralStrike, _vol, _param);
        return result;
    }

    ///@dev call getMinCollateralForShortCall and return
    function getMinCollateralForShortCall(
        uint256 _shortAmount,
        uint256 _strike,
        uint256 _expiry,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) external view returns (uint256) {
        uint256 result = AdvancedMarginMath.getMinCollateralForShortCall(_shortAmount, _strike, _expiry, _spot, _vol, params);
        return result;
    }

    ///@dev call getMinCollateralForShortPut and return
    function getMinCollateralForShortPut(
        uint256 _shortAmount,
        uint256 _strike,
        uint256 _expiry,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) external view returns (uint256) {
        uint256 result = AdvancedMarginMath.getMinCollateralForShortPut(_shortAmount, _strike, _expiry, _spot, _vol, params);
        return result;
    }

    function getTimeDecay(uint256 _expiry, ProductMarginParams memory params) external view returns (uint256) {
        uint256 result = AdvancedMarginMath.getTimeDecay(_expiry, params);
        return result;
    }

    function getMinCollateralInStrike(
        AdvancedMarginDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory _params
    ) external view returns (uint256 minCollatValueInStrike) {
        uint256 result = AdvancedMarginMath.getMinCollateralInStrike(_account, _spot, _vol, _params);
        return result;
    }
}

/**
 * Test if the formula is working properly for min collateral calculation:
 * Desmos file with same parameter can be found here:
 *             https://www.desmos.com/calculator/mx6le8msfo
 */
contract AdvancedMarginMathTest is Test {
    uint256 public constant base = UNIT;
    uint256 public today;

    AdvancedMarginMathTester tester;

    function setUp() public {
        today = block.timestamp;

        tester = new AdvancedMarginMathTester();
    }

    function testMinCollateralOTMCall() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 4000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        uint256 minCollat = tester.getMinCollateralForShortCall(amount, strike, expiry, spot, vol, getDefaultConfig());
        assertEq(minCollat, 483262500); // 483.2 USD

        // get min collat in strike should return same answer
        AdvancedMarginDetail memory acc;
        acc.callAmount = base;
        acc.shortCallStrike = strike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();
        assertEq(tester.getMinCollateralInStrike(acc, spot, vol, config), 483262500);

        // spot decrease, min collateral also decrease
        spot = 2500 * base;
        uint256 minCollat2 = tester.getMinCollateralForShortCall(amount, strike, expiry, spot, vol, getDefaultConfig());
        assertEq(minCollat2, 246562500); // 246 USD
    }

    function testMinCollateralITMCall() public {
        uint256 spot = 3250 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;

        uint256 minCollat = tester.getMinCollateralForShortCall(amount, strike, expiry, spot, UNIT, getDefaultConfig());
        assertEq(minCollat, 723400000); // 723 USD

        // spot increase, min collateral also increase
        spot = 4000 * base;
        uint256 minCollat2 = tester.getMinCollateralForShortCall(amount, strike, expiry, spot, UNIT, getDefaultConfig());
        assertEq(minCollat2, 1473400000); // 1473.5 USD
    }

    function testMinCollateralOTMPut() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        uint256 minCollat = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, getDefaultConfig());
        assertEq(minCollat, 405771428); // ~406 USD

        // get min collat in strike should return same answer
        AdvancedMarginDetail memory acc;
        acc.putAmount = base;
        acc.shortPutStrike = strike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();
        assertEq(tester.getMinCollateralInStrike(acc, spot, vol, config), 405771428);

        // increasing spot price, the min collateral stay the same
        spot = 4000 * base;
        uint256 minCollat2 = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, getDefaultConfig());
        assertEq(minCollat2, 355050000); // 355 USD
    }

    function testMinCollateralITMPut() public {
        uint256 spot = 3250 * base;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        ProductMarginParams memory config = getDefaultConfig();

        uint256 minCollat = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat, 762850000); // 762 USD

        // decrease spot price, the min collateral increase
        spot = 2000 * base;
        uint256 minCollat2 = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat2, 1815600000); // 1815 USD

        // capped at strike price
        spot = 0;
        uint256 minCollat3 = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat3, 3500000000); // 3500 USD
    }

    function testMinCollateralSpotIsZero() public {
        uint256 spot = 0;
        uint256 amount = 1 * base;
        uint256 strike = 3500 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;
        ProductMarginParams memory config = getDefaultConfig();

        // edge cases: when spot is zero, ask for full collateral.
        uint256 minCollat = tester.getMinCollateralForShortPut(amount, strike, expiry, spot, vol, config);
        assertEq(minCollat, strike);
    }

    function testFuzzMinCollateralCallSpreadShouldNotExceedMaxLoss(uint64 spot) public {
        uint256 amount = 1 * base;
        uint256 shortStrike = 3000 * base;
        uint256 longStrike = 3200 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        AdvancedMarginDetail memory acc;
        acc.callAmount = amount;
        acc.longCallStrike = longStrike;
        acc.shortCallStrike = shortStrike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();

        uint256 maxLoss = longStrike - shortStrike;
        uint256 res = tester.getMinCollateralInStrike(acc, uint256(spot), vol, config);
        assertEq(res <= maxLoss, true);
    }

    function testFuzzMinCollateralPutSpreadShouldNotExceedMaxLoss(uint64 spot) public {
        uint256 amount = 1 * base;
        uint256 shortStrike = 1800 * base;
        uint256 longStrike = 1600 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        AdvancedMarginDetail memory acc;
        acc.putAmount = amount;
        acc.longPutStrike = longStrike;
        acc.shortPutStrike = shortStrike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();

        uint256 maxLoss = shortStrike - longStrike;
        uint256 res = tester.getMinCollateralInStrike(acc, uint256(spot), vol, config);
        assertEq(res <= maxLoss, true);
    }

    function testFuzzMinCollatForDebitPutSpread(uint64 spot, uint256 shortStrike, uint256 longStrike) public {
        vm.assume(shortStrike < longStrike);
        AdvancedMarginDetail memory acc;
        acc.putAmount = 1 * base;
        acc.longPutStrike = longStrike;
        acc.shortPutStrike = shortStrike;
        acc.expiry = today + 21 days;

        uint256 vol = UNIT;
        ProductMarginParams memory config = getDefaultConfig();

        uint256 collat = tester.getMinCollateralInStrike(acc, uint256(spot), vol, config);
        assertEq(collat, 0);
    }

    function testFuzzMinCollatForDebitCallSpread(uint64 spot, uint256 shortStrike, uint256 longStrike) public {
        vm.assume(shortStrike > longStrike);
        vm.assume(longStrike > 0);
        AdvancedMarginDetail memory acc;
        acc.callAmount = 1 * base;
        acc.longCallStrike = longStrike;
        acc.shortCallStrike = shortStrike;
        acc.expiry = today + 21 days;

        uint256 vol = UNIT;
        ProductMarginParams memory config = getDefaultConfig();

        uint256 collat = tester.getMinCollateralInStrike(acc, uint256(spot), vol, config);
        assertEq(collat, 0);
    }

    function testAccountShortStrangle() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 callStrike = 4000 * base;
        uint256 putStrike = 3000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        // account holds a strangle (1 short call + 1 short put)
        AdvancedMarginDetail memory acc;
        acc.callAmount = amount;
        acc.putAmount = amount;
        acc.shortCallStrike = callStrike;
        acc.shortPutStrike = putStrike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();

        // max of 483262500 and 405771428
        assertEq(tester.getMinCollateralInStrike(acc, spot, vol, config), 483262500);
    }

    function testAccountDoubleShortBothITM() public {
        // if an account has 2 options, but the strike cross
        // the margin requirement is the sum of 2.
        uint256 spot = 3250 * base;
        uint256 amount = 1 * base;
        uint256 callStrike = 3000 * base;
        uint256 putStrike = 3500 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        // account holds 1 short call + 1 short put (both ITM)
        AdvancedMarginDetail memory acc;
        acc.callAmount = amount;
        acc.putAmount = amount;
        acc.shortCallStrike = callStrike;
        acc.shortPutStrike = putStrike;
        acc.expiry = expiry;
        ProductMarginParams memory config = getDefaultConfig();

        // sum of 762850000 (put) and 723400000
        assertEq(tester.getMinCollateralInStrike(acc, spot, vol, config), 723400000 + 762850000);

        // if only the call is ITM, collateral requirement is reduced
        spot = 3600 * base;
        assertEq(tester.getMinCollateralInStrike(acc, spot, vol, config), 1073_400000);
    }

    function testCannotCalculateMarginRequirementWithoutProperConfig() public {
        uint256 spot = 3250 * base;
        uint256 amount = 1 * base;
        uint256 callStrike = 3000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        // account holds 1 short call + 1 short put (both ITM)
        AdvancedMarginDetail memory acc;
        acc.callAmount = amount;
        acc.shortCallStrike = callStrike;
        acc.expiry = expiry;

        // empty config
        ProductMarginParams memory config;

        vm.expectRevert(AM_NoConfig.selector);
        tester.getMinCollateralInStrike(acc, spot, vol, config);
    }

    function testTimeDecayIsZeroOnPassedTimestamp() public {
        uint256 expiry = block.timestamp - 1;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = tester.getTimeDecay(expiry, config);
        assertEq(decay, 0);
    }

    function testTimeDecayValueLowerBond() public {
        uint256 expiry = today + 8000 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = tester.getTimeDecay(expiry, config);
        assertEq(decay, config.rLower);
    }

    function testTimeDecayValueUpperBond() public {
        uint256 expiry = today + 180 days + 10 seconds;
        ProductMarginParams memory config = getDefaultConfig();
        uint256 decay = tester.getTimeDecay(expiry, config);
        assertEq(decay, config.rUpper);
    }

    function testTimeDecayValue90Days() public {
        uint256 expiry = today + 90 days;
        uint256 decay = tester.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 2645); // 26.45%
    }

    function testTimeDecayValue30Days() public {
        uint256 expiry = today + 30 days;
        uint256 decay = tester.getTimeDecay(expiry, getDefaultConfig());
        assertEq(decay, 1773); // 17.73%
    }

    function testMinCollatInStrikeOnEmptyAccount() public {
        // test empty account
        ProductMarginParams memory config = getDefaultConfig();
        AdvancedMarginDetail memory emptyAcc = AdvancedMarginDetail({
            callAmount: 0,
            putAmount: 0,
            longCallStrike: 0,
            shortCallStrike: 0,
            longPutStrike: 0,
            shortPutStrike: 0,
            expiry: 0,
            collateralAmount: 0,
            productId: 0
        });
        assertEq(tester.getMinCollateralInStrike(emptyAcc, 3000 * UNIT, UNIT, config), 0);
    }

    /* ----------------- *
     *  getMinCollateral *
     * ----------------- */

    function testMinCollateralShouldConvertPriceBaseOnProductDetail() public {
        uint256 spot = 3500 * base;
        uint256 amount = 1 * base;
        uint256 strike = 4000 * base;
        uint256 expiry = today + 21 days;
        uint256 vol = UNIT;

        // get min collat in strike should return same answer
        AdvancedMarginDetail memory acc;
        acc.callAmount = amount;
        acc.shortCallStrike = strike;
        acc.expiry = expiry;

        ProductMarginParams memory config = getDefaultConfig();

        ProductDetails memory assetInfo;
        assetInfo.underlying = address(1);
        assetInfo.collateral = address(2); // collat is strike
        assetInfo.strike = address(2);

        uint256 minCollatInUSD = 483262500;

        uint256 collat = tester.getMinCollateral(acc, assetInfo, spot, 0, vol, config);
        assertEq(collat, minCollatInUSD);

        // should convert if collateral is not strike (USDC)
        assetInfo.collateral = address(3);
        uint256 collatPrice = 500 * base;

        uint256 collatConverted = tester.getMinCollateral(acc, assetInfo, spot, collatPrice, vol, config);
        assertEq(collatConverted, minCollatInUSD * UNIT / collatPrice);
    }

    function getDefaultConfig() internal pure returns (ProductMarginParams memory config) {
        return ProductMarginParams({
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
