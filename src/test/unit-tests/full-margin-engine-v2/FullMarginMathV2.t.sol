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
contract TestStructuresFMMV2 is Test {
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

    function testVerifyInputs2() public {
        callWeights[2] = 0;

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
        vm.expectRevert(FullMarginMathV2.FMMV2_InvalidCallWeight.selector);
        detail.getMinCollateral();
    }

    function testVerifyInputs3() public {
        putWeights = new int256[](3);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;
        putWeights[2] = 1 * sUNIT;

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
        vm.expectRevert(FullMarginMathV2.FMMV2_InvalidPutLengths.selector);
        detail.getMinCollateral();
    }

    function testVerifyInputs4() public {
        callWeights = new int256[](3);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;
        callWeights[2] = 1 * sUNIT;

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
        vm.expectRevert(FullMarginMathV2.FMMV2_InvalidCallLengths.selector);
        detail.getMinCollateral();
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 28000 * sUNIT);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 3000 * sUNIT);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 33000 * sUNIT);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 28000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginSimpleITMPut() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 22000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[0]));
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginSimpleOTMPut() public {
        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = 15000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[0]));
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginSimpleITMCall() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 15000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    function testMarginSimpleOTMCall() public {
        putWeights = new int256[](0);
        putStrikes = new uint256[](0);

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 22000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, 1 * sUNIT);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 1);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginLongBinaryPut() public {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginShortBinaryPut() public {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 1);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, (1 * sUNIT) / 22000);
    }

    function testMarginCallSpreadSameUnderlyingCollateralBiggerNumbers() public {
        callWeights = new int256[](2);
        callWeights[0] = -100000 * sUNIT;
        callWeights[1] = 100000 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21000 * UNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, (1000_00000 * sUNIT) / 22000);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testMarginCallSpreadWithCash() public {
        callWeights = new int256[](2);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 21000 * UNIT;
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
            collateralId: 1,
            collateralDecimals: UNIT_DECIMALS,
            spotPrice: spotPrice,
            expiry: 0
        });

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 1000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testConversion() public {
        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 17000 * UNIT;

        putWeights = new int256[](1);
        putWeights[0] = -1 * sUNIT;

        putStrikes = new uint256[](1);
        putStrikes[0] = callStrikes[0];

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

        (int256 cashNeeded1, int256 underlyingNeeded1) = detail.getMinCollateral();
        assertEq(cashNeeded1, 17000 * sUNIT);
        assertEq(underlyingNeeded1, 1 * sUNIT);

        callWeights[0] = 314 * callWeights[0];
        detail = FullMarginDetailV2({
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

        (int256 cashNeeded2, int256 underlyingNeeded2) = detail.getMinCollateral();
        assertEq(cashNeeded1, cashNeeded2);
        assertEq(underlyingNeeded2, 314 * underlyingNeeded1);
    }
}

contract TestVanillaCallFMMV2 is Test {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }
}

contract TestVanillaPutFMMV2 is Test {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, 18000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }
}

contract TestStrangles is Test {
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

        callWeights = new int256[](1);
        callWeights[0] = -1 * sUNIT;

        callStrikes = new uint256[](1);
        callStrikes[0] = 20000 * UNIT;

        spotPrice = 19000 * UNIT;
    }

    function testShortStrangles() public {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[0]));
        assertEq(underlyingNeeded, -callWeights[0]);
    }

    function testLongStrangle() public {
        putWeights[0] = 1 * sUNIT;
        callWeights[0] = 1 * sUNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, sZERO);
    }

    function testStrangleSpread() public {
        putWeights = new int256[](2);
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        callWeights = new int256[](2);
        callWeights[0] = -1 * sUNIT;
        callWeights[1] = 1 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 20000 * UNIT;
        callStrikes[1] = 21000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[0] - putStrikes[1]));
        assertEq(underlyingNeeded, sZERO);
    }
}

contract TestCornerCases is Test {
    using FullMarginMathV2 for FullMarginDetailV2;

    uint256 private spotPrice;

    int256[] private putWeights;
    uint256[] private putStrikes;

    int256[] private callWeights;
    uint256[] private callStrikes;

    function setUp() public {
        putWeights = new int256[](2);
        putWeights[0] = 1 * sUNIT;
        putWeights[1] = -2 * sUNIT;

        putStrikes = new uint256[](2);
        putStrikes[0] = 18000 * UNIT;
        putStrikes[1] = 17000 * UNIT;

        callWeights = new int256[](2);
        callWeights[0] = 1 * sUNIT;
        callWeights[1] = -2 * sUNIT;

        callStrikes = new uint256[](2);
        callStrikes[0] = 20000 * UNIT;
        callStrikes[1] = 21000 * UNIT;

        spotPrice = 19000 * UNIT;
    }

    function testOneByTwoCall() public {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, sZERO);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    function testOneByTwoCall2() public {
        putStrikes = new uint256[](0);
        putWeights = new int256[](0);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(underlyingNeeded, 1 * sUNIT);
        assertEq(cashNeeded, sZERO);
    }

    function testPotentialBreakOnZeroWeight() public {
        putWeights[0] = 0;
        putWeights[1] = 0;
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
        vm.expectRevert(FullMarginMathV2.FMMV2_InvalidPutWeight.selector);
        detail.getMinCollateral();
    }

    function testOneByTwoPut() public {
        callStrikes = new uint256[](0);
        callWeights = new int256[](0);
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[1]) - 1000 * sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testIronCondor() public {
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        assertEq(cashNeeded, int256(putStrikes[1]) - 1000 * sUNIT);
        assertEq(underlyingNeeded, 1 * sUNIT);
    }

    function testUpAndDown1() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        int256 cashRequired = -putWeights[0] * int256(putStrikes[0]) - putWeights[1] * int256(putStrikes[1]);
        assertEq(cashNeeded, cashRequired);
        assertEq(underlyingNeeded, sZERO);
    }

    function testUpAndDown2() public {
        putWeights[0] = 16 * sUNIT;
        putWeights[1] = -18 * sUNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        int256 cashRequired = -putWeights[0] * int256(putStrikes[0]) - putWeights[1] * int256(putStrikes[1]);
        assertEq(cashNeeded, cashRequired / sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testUpAndDown3() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
        callWeights = new int256[](1);
        callWeights[0] = 1 * sUNIT;
        callStrikes = new uint256[](1);
        callStrikes[0] = 20000 * UNIT;

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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        int256 cashRequired = -putWeights[0] * int256(putStrikes[0]) - putWeights[1] * int256(putStrikes[1]);
        assertEq(cashNeeded, cashRequired / sUNIT);
        assertEq(underlyingNeeded, sZERO);
    }

    function testUpAndDown4() public {
        putWeights[0] = 17 * sUNIT;
        putWeights[1] = -18 * sUNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        int256 cashRequired = -putWeights[0] * int256(putStrikes[0]) - putWeights[1] * int256(putStrikes[1]);
        assertEq(cashNeeded, cashRequired / sUNIT);
        assertEq(underlyingNeeded, -int256(callWeights[0] + callWeights[1]));
    }

    function testPutGreaterThanCalls() public {
        putWeights[0] = -1 * sUNIT;
        putWeights[1] = 1 * sUNIT;

        putStrikes[0] = 2500 * UNIT;
        putStrikes[1] = 100 * UNIT;

        callWeights[1] = 1 * sUNIT;
        callWeights[1] = -1 * sUNIT;

        callStrikes[0] = 300 * UNIT;
        callStrikes[1] = 200 * UNIT;
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

        (int256 cashNeeded, int256 underlyingNeeded) = detail.getMinCollateral();
        int256 cashRequired = -putWeights[0] * int256(putStrikes[0]) - putWeights[1] * int256(putStrikes[1]);
        assertEq(cashNeeded, cashRequired / sUNIT);
        assertEq(underlyingNeeded, -int256(callWeights[0] + callWeights[1]));
    }
}
