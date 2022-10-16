// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {FullMarginMathV2} from "../../../core/engines/full-margin-v2/FullMarginMathV2.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

import "../../utils/Console.sol";

/**
 * test full margin calculation for complicated structure
 */
contract TestStructures_FMMV2 is Test {
    using FullMarginMathV2 for FullMarginDetailV2;

    uint256 private spotPrice;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17000 * UNIT;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](4);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = -8 * sUNIT;
        callWeights[2] = 16 * sUNIT;
        callWeights[3] = -6 * sUNIT;

        callStrikes = new uint256[](4);
        callStrikes[0] = 21000 * UNIT;
        callStrikes[1] = 22000 * UNIT;
        callStrikes[2] = 25000 * UNIT;
        callStrikes[3] = 26000 * UNIT;

        spotPrice = 19000 * UNIT;
    }

    function testMarginRequirement1() public {
        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, bool canUseRiskCol, int256 inRiskCol) = detail
            .getMinCollateral();
        assertEq(collateralNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
        assertEq(canUseRiskCol, true);
        assertEq(inRiskCol, 1120000);
    }

    function testMarginRequirement2() public {
        callWeights[3] = -7 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginRequirement3() public {
        callWeights[3] = -8 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, 3000 * sUNIT);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    function testMarginRequirement4() public {
        putWeights[0] = -3 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, 33000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginUnsortedStrikes() public {
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -1 * sUNIT;

        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callWeights[0] = -8 * sUNIT;
        callWeights[1] = -6 * sUNIT;
        callWeights[2] = -1 * sUNIT;
        callWeights[3] = 16 * sUNIT;

        callStrikes[0] = 22000 * UNIT;
        callStrikes[1] = 26000 * UNIT;
        callStrikes[2] = 21000 * UNIT;
        callStrikes[3] = 25000 * UNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginPutSpread1() public {
        putWeights = new int256[](2);
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, bool canUseRiskCol, int256 inRiskCol) = detail
            .getMinCollateral();
        assertEq(collateralNeeded, 1);
        assertEq(underlyingNeeded, sZERO);
        assertEq(canUseRiskCol, false);
        assertEq(inRiskCol, 0);
    }

    function testMarginPutSpread2() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginBinaryPutOption() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17999_999999;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginCallSpreadSameUnderlyingCollateral() public {
        callWeights = new int256[](2);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21999 * UNIT;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, bool canUseRiskCol, int256 inRiskCol) = detail
            .getMinCollateral();
        assertEq(collateralNeeded, 0);
        assertEq(underlyingNeeded, 45);
        assertEq(canUseRiskCol, true);
        assertEq(inRiskCol, (1 * sUNIT) / 22000);
        consoleG.logInt(inRiskCol);
    }

    function testMarginCallSpreadBasicallyAnOption() public {
        callWeights = new int256[](2);
        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21999_999999;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginBinaryCallOption() public {
        callWeights = new int256[](2);
        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21999_999999;
        callStrikes[1] = 22000 * UNIT;

        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }
}

contract TestVanillaCall_FMMV2 is Test {
    using FullMarginMathV2 for FullMarginDetailV2;

    uint256 private spotPrice;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 21000 * UNIT;

        spotPrice = 19000 * UNIT;
    }

    function testMarginRequirementVanillaCall1() public {
        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 0,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, sZERO);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }
}

contract TestVanillaPut_FMMV2 is Test {
    using FullMarginMathV2 for FullMarginDetailV2;

    uint256 private spotPrice;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 18000 * UNIT;

        callWeights = new int256[](0);
        callStrikes = new uint256[](0);

        spotPrice = 19000 * UNIT;
    }

    function testMarginRequirement1() public {
        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            underlyingId: 0,
            underlyingDecimals: UNIT_DECIMALS,
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 collateralNeeded, int256 underlyingNeeded, , ) = detail.getMinCollateral();
        assertEq(collateralNeeded, 18000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }
}
