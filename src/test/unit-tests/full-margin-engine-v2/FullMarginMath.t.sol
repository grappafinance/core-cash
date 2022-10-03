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
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, ZERO);
    }

    function testMarginRequirement3() public {
        callWeights[3] = -7 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * UNIT);
        assertEq(underlyingNeeded, ZERO);
    }

    function testMarginRequirement2() public {
        callWeights[3] = -8 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 3000 * UNIT);
        assertEq(underlyingNeeded, 1 * UNIT);
    }

    function testMarginRequirement4() public {
        putWeights[0] = -3 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 34000 * UNIT);
        assertEq(underlyingNeeded, ZERO);
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

    function testMarginRequirement1() public {
        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, ZERO);
        assertEq(underlyingNeeded, 1 * UNIT);
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
            spotPrice: spotPrice
        });

        (uint256 collateralNeeded, uint256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 18000 * UNIT);
        assertEq(underlyingNeeded, ZERO);
    }
}
