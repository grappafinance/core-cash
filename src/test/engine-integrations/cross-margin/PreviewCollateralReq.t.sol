// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../core/engines/cross-margin/AccountUtil.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";
import "../../../core/engines/cross-margin//AccountUtil.sol";

contract PreviewCollateralReqBase is CrossMarginFixture {
    uint256 public expiry;

    uint8 constant PUT = uint8(0);
    uint8 constant CALL = uint8(2);

    uint8 constant CASH = uint8(0);
    uint8 constant PHYSICAL = uint8(1);

    struct OptionPosition {
        DerivativeType derivativeType;
        SettlementType settlementType;
        uint256 strike;
        int256 amount;
    }

    function _optionPosition(uint8 derivativeType, uint8 settlementType, uint256 strike, int256 amount)
        internal
        pure
        returns (OptionPosition memory op)
    {
        if (strike <= UNIT) strike = strike * UNIT;
        return OptionPosition(DerivativeType(derivativeType), SettlementType(settlementType), strike, amount * sUNIT);
    }

    function _previewMinCollateral(OptionPosition[] memory postions) internal view returns (Balance[] memory balances) {
        (Position[] memory shorts, Position[] memory longs) = _convertPositions(postions);
        balances = engine.previewMinCollateral(shorts, longs);
    }

    function _convertPositions(OptionPosition[] memory positions)
        internal
        view
        returns (Position[] memory shorts, Position[] memory longs)
    {
        for (uint256 i = 0; i < positions.length; i++) {
            OptionPosition memory position = positions[i];

            uint256 tokenId =
                DerivativeType.CALL == position.derivativeType ? _callTokenId(position.strike) : _putTokenId(position.strike);

            if (position.amount < 0) {
                shorts = AccountUtil.append(shorts, Position(tokenId, uint64(uint256(-position.amount))));
            } else {
                longs = AccountUtil.append(longs, Position(tokenId, uint64(uint256(position.amount))));
            }
        }
    }

    function _callTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(DerivativeType.CALL, SettlementType.CASH, pidEthCollat, expiry, _strikePrice, 0);
    }

    function _putTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(DerivativeType.PUT, SettlementType.CASH, pidUsdcCollat, expiry, _strikePrice, 0);
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function testIgnore() public {}
}

contract PreviewCollateralReq_CMM is PreviewCollateralReqBase {
    function testMarginRequirement1() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, CASH, 21000, -1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -8);
        positions[2] = _optionPosition(CALL, CASH, 25000, 16);
        positions[3] = _optionPosition(CALL, CASH, 26000, -6);
        positions[4] = _optionPosition(PUT, CASH, 17000, -1);
        positions[5] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginRequirement2() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, CASH, 21000, -1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -8);
        positions[2] = _optionPosition(CALL, CASH, 25000, 16);
        positions[3] = _optionPosition(CALL, CASH, 26000, -7);
        positions[4] = _optionPosition(PUT, CASH, 17000, -1);
        positions[5] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginRequirement3() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, CASH, 21000, -1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -8);
        positions[2] = _optionPosition(CALL, CASH, 25000, 16);
        positions[3] = _optionPosition(CALL, CASH, 26000, -8);
        positions[4] = _optionPosition(PUT, CASH, 17000, -1);
        positions[5] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testMarginRequirement4() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, CASH, 21000, -1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -8);
        positions[2] = _optionPosition(CALL, CASH, 25000, 16);
        positions[3] = _optionPosition(CALL, CASH, 26000, -6);
        positions[4] = _optionPosition(PUT, CASH, 17000, -3);
        positions[5] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 33000 * UNIT);
    }

    function testMarginUnsortedStrikes() public {
        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = _optionPosition(CALL, CASH, 22000, -8);
        positions[1] = _optionPosition(CALL, CASH, 26000, -6);
        positions[2] = _optionPosition(CALL, CASH, 21000, -1);
        positions[3] = _optionPosition(CALL, CASH, 25000, 16);
        positions[4] = _optionPosition(PUT, CASH, 18000, 1);
        positions[5] = _optionPosition(PUT, CASH, 17000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * UNIT);
    }

    function testMarginSimpleITMPut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(PUT, CASH, 22000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 22000 * UNIT);
    }

    function testMarginSimplePut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(PUT, CASH, 15000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 15000 * UNIT);
    }

    function testMarginSimplePhysicalPut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(PUT, PHYSICAL, 15000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 15000 * UNIT);
    }

    function testMarginSimplePhysicalCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(CALL, PHYSICAL, 15000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginSimpleITMCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(CALL, CASH, 15000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginSimpleOTMCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(CALL, CASH, 22000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginLongBinaryPut() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17999_999999, -1);
        positions[1] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testMarginShortBinaryPut() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17999_999999, 1);
        positions[1] = _optionPosition(PUT, CASH, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1);
    }

    function testMarginCallSpreadSameUnderlyingCollateral() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 21999, -1);
        positions[1] = _optionPosition(CALL, CASH, 22000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, ((1 * UNIT) / 22000) * (10 ** (18 - UNIT_DECIMALS)));
    }

    function testMarginCallSpreadSameUnderlyingCollateralDifferentSettlement() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 21999, -1);
        positions[1] = _optionPosition(CALL, PHYSICAL, 22000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, ((1 * UNIT) / 22000) * (10 ** (18 - UNIT_DECIMALS)));
    }

    function testMarginCallSpreadSameUnderlyingCollateralBiggerNumbers() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 21000, -100000);
        positions[1] = _optionPosition(CALL, CASH, 22000, 100000);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, ((100000 * 1000 * UNIT) / 22000) * (10 ** (18 - UNIT_DECIMALS)));
    }

    function testMarginBinaryCallOption() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 21999_999999, 1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testConversion() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 17000, -1);
        positions[1] = _optionPosition(PUT, CASH, 17000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 17000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);

        positions[0] = _optionPosition(CALL, CASH, 17000, -314);

        balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 17000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 314 * 1e18);
    }

    function testMarginRequirementsVanillaCall() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(CALL, CASH, 21000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testMarginRequirementsVanillaPut() public {
        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = _optionPosition(PUT, CASH, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
    }

    function testShortStrangles() public {
        OptionPosition[] memory positions = new OptionPosition[](2);

        positions[0] = _optionPosition(CALL, CASH, 20000, -1);
        positions[1] = _optionPosition(PUT, CASH, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testShortStranglesWithDiffSettlements() public {
        OptionPosition[] memory positions = new OptionPosition[](2);

        positions[0] = _optionPosition(CALL, CASH, 20000, -1);
        positions[1] = _optionPosition(PUT, PHYSICAL, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testLongStrangles() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(CALL, CASH, 20000, 1);
        positions[1] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testStrangleSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = _optionPosition(CALL, CASH, 20000, -1);
        positions[1] = _optionPosition(CALL, CASH, 21000, 1);
        positions[2] = _optionPosition(PUT, CASH, 17000, -1);
        positions[3] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testStrangleSpread2() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = _optionPosition(CALL, CASH, 20000, -1);
        positions[1] = _optionPosition(CALL, CASH, 21000, 1);
        positions[2] = _optionPosition(PUT, CASH, 17000, 1);
        positions[3] = _optionPosition(PUT, CASH, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testOneByTwoCall() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = _optionPosition(CALL, CASH, 20000, 1);
        positions[1] = _optionPosition(CALL, CASH, 21000, -2);
        positions[2] = _optionPosition(PUT, CASH, 0, 0);
        positions[3] = _optionPosition(PUT, CASH, 0, 0);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testOneByTwoPut() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = _optionPosition(CALL, CASH, 0, 0);
        positions[1] = _optionPosition(CALL, CASH, 0, 0);
        positions[2] = _optionPosition(PUT, CASH, 17000, -2);
        positions[3] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 16000 * UNIT);
    }

    function testIronCondor() public {
        OptionPosition[] memory positions = new OptionPosition[](4);

        positions[0] = _optionPosition(CALL, CASH, 20000, 1);
        positions[1] = _optionPosition(CALL, CASH, 21000, -2);
        positions[2] = _optionPosition(PUT, CASH, 17000, -2);
        positions[3] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 16000 * UNIT);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }

    function testUpAndDown1() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17000, -18);
        positions[1] = _optionPosition(PUT, CASH, 18000, 17);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testLongPutSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17000, -1);
        positions[1] = _optionPosition(PUT, CASH, 18000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testShortPutSpread() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17000, 1);
        positions[1] = _optionPosition(PUT, CASH, 18000, -1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * UNIT);
    }

    function testUpAndDown2() public {
        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = _optionPosition(PUT, CASH, 17000, -18);
        positions[1] = _optionPosition(PUT, CASH, 18000, 16);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 18000 * UNIT);
    }

    function testUpAndDown3() public {
        OptionPosition[] memory positions = new OptionPosition[](3);
        positions[0] = _optionPosition(CALL, CASH, 20000, 1);
        positions[1] = _optionPosition(PUT, CASH, 17000, -18);
        positions[2] = _optionPosition(PUT, CASH, 18000, 17);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 0);
    }

    function testUpAndDown4() public {
        OptionPosition[] memory positions = new OptionPosition[](4);
        positions[0] = _optionPosition(CALL, CASH, 20000, 1);
        positions[1] = _optionPosition(CALL, CASH, 21000, -2);
        positions[2] = _optionPosition(PUT, CASH, 17000, -18);
        positions[3] = _optionPosition(PUT, CASH, 18000, 17);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
    }

    function testPutGreaterThanCalls() public {
        OptionPosition[] memory positions = new OptionPosition[](4);
        positions[0] = _optionPosition(CALL, CASH, 23000, 1);
        positions[1] = _optionPosition(CALL, CASH, 22000, -1);
        positions[2] = _optionPosition(PUT, CASH, 25000, -1);
        positions[3] = _optionPosition(PUT, CASH, 10000, 1);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 15000 * UNIT);
    }
}
