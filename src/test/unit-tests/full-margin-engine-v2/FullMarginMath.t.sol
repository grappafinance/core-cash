// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {FullMarginMathV2} from "../../../core/engines/full-margin-v2/FullMarginMathV2.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * test full margin calculation for complicated structure
 */
contract TestCall_FMMV2 is Test {
    using FullMarginMathV2 for FullMarginDetailV2;

    uint256 private spotPrice;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](2);
        putWeights[0] = -sUNIT;
        putWeights[1] = sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 17000 * UNIT;
        putStrikes[1] = 18000 * UNIT;

        callWeights = new int256[](4);
        callWeights[0] = -sUNIT;
        callWeights[1] = -8 * sUNIT;
        callWeights[2] = 16 * sUNIT;
        callWeights[3] = -8 * sUNIT;

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

        (int256 collateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 3000 * sUNIT);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    function testMarginRequirement2() public {
        callWeights[3] = -6 * sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (int256 collateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
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

        (int256 collateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginRequirement4() public {
        putWeights[0] = -3 * sUNIT;
        putWeights[1] = sUNIT;

        FullMarginDetailV2 memory detail = FullMarginDetailV2({
            putWeights: putWeights,
            putStrikes: putStrikes,
            callWeights: callWeights,
            callStrikes: callStrikes,
            spotPrice: spotPrice
        });

        (int256 collateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(collateralNeeded, 38000 * sUNIT);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    // function testMarginRequireMultipleCall() public {
    //     uint256 shortAmount = 5 * UNIT;
    //     FullMarginDetail memory detail = FullMarginDetail({
    //         shortAmount: shortAmount,
    //         longStrike: 0,
    //         shortStrike: 3000 * UNIT,
    //         collateralAmount: 0,
    //         collateralDecimals: 6,
    //         collateralizedWithStrike: false,
    //         tokenType: TokenType.CALL
    //     });

    //     uint256 collat = detail.getMinCollateral();
    //     uint256 expectedRequirement = shortAmount;

    //     assertEq(collat, expectedRequirement);
    // }

    // function testMarginRequireMultipleCallDiffDecimals() public {
    //     uint256 shortAmount = 5 * UNIT;
    //     FullMarginDetail memory detail = FullMarginDetail({
    //         shortAmount: shortAmount,
    //         longStrike: 0,
    //         shortStrike: 3000 * UNIT,
    //         collateralAmount: 0,
    //         collateralDecimals: 18,
    //         collateralizedWithStrike: false,
    //         tokenType: TokenType.CALL
    //     });

    //     uint256 collat = detail.getMinCollateral();
    //     uint256 expectedRequirement = 5 * 1e18;

    //     assertEq(collat, expectedRequirement);
    // }
}

// /**
//  * test full margin calculation for simple put
//  */
// contract FullMarginMathTestPut is Test {
//     using FullMarginMath for FullMarginDetail;

//     function testMarginRequirePut() public {
//         FullMarginDetail memory detail = FullMarginDetail({
//             shortAmount: UNIT,
//             longStrike: 0,
//             shortStrike: 3000 * UNIT,
//             collateralAmount: 0,
//             collateralDecimals: 6,
//             collateralizedWithStrike: true,
//             tokenType: TokenType.PUT
//         });

//         uint256 collat = detail.getMinCollateral();
//         uint256 expectedRequirement = 3000 * UNIT;
//         assertEq(collat, expectedRequirement);
//     }

//     function testMarginRequireMultiplePut() public {
//         uint256 shortAmount = 5 * UNIT;
//         FullMarginDetail memory detail = FullMarginDetail({
//             shortAmount: shortAmount,
//             longStrike: 0,
//             shortStrike: 3000 * UNIT,
//             collateralAmount: 0,
//             collateralDecimals: 6,
//             collateralizedWithStrike: true,
//             tokenType: TokenType.PUT
//         });

//         uint256 collat = detail.getMinCollateral();
//         uint256 expectedRequirement = shortAmount * 3000;

//         assertEq(collat, expectedRequirement);
//     }

//     function testMarginRequireMultiplePutDiffDecimals() public {
//         uint256 shortAmount = 5 * UNIT;
//         FullMarginDetail memory detail = FullMarginDetail({
//             shortAmount: shortAmount,
//             longStrike: 0,
//             shortStrike: 3000 * UNIT,
//             collateralAmount: 0,
//             collateralDecimals: 18,
//             collateralizedWithStrike: true,
//             tokenType: TokenType.PUT
//         });

//         uint256 collat = detail.getMinCollateral();
//         uint256 expectedRequirement = 5 * 3000 * 1e18;

//         assertEq(collat, expectedRequirement);
//     }
// }
