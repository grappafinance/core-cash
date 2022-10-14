// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/errors.sol";

import "../../../test/utils/Console.sol";

/**
 * @title   FullMarginMathV2
 * @notice  this library is in charge of calculating the min collateral for a given simple margin account
 */
library FullMarginMathV2 {
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];
    using SafeCast for int256;
    using SafeCast for uint256;

    struct PayoutsParams {
        uint256[] pois;
        uint256[] strikes;
        int256[] weights;
        int256 underlyingWeight;
        uint256 spotPrice;
        int256 intrinsicValue;
    }

    error FMMV2_InvalidPutLengths();

    error FMMV2_InvalidCallLengths();

    error FMMV2_BadPoints();

    error FMMV2_InvalidLeftPointLength();

    error FMMV2_InvalidRightPointLength();

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return cashCollateralNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(FullMarginDetailV2 memory _detail)
        public
        view
        returns (int256 cashCollateralNeeded, int256 underlyingNeeded)
    {
        (
            uint256[] memory strikes,
            int256[] memory weights,
            int256 underlyingWeight,
            int256 intrinsicValue
        ) = convertPutsToCalls(_detail);

        // consoleG.log("strikes");
        // consoleG.log(strikes);

        // consoleG.log("weights");
        // consoleG.log(weights);

        uint256 minStrike = strikes.min();
        uint256 maxStrike = strikes.max();

        uint256[] memory pois = createPois(_detail, strikes, minStrike, maxStrike);

        int256[] memory payouts = calculatePayouts(
            PayoutsParams(pois, strikes, weights, underlyingWeight, _detail.spotPrice, intrinsicValue)
        );

        if (_detail.callStrikes.length > 0) underlyingNeeded = getUnderlyingNeeded(pois, payouts);

        if (_detail.putStrikes.length > 0)
            cashCollateralNeeded = getCashCollateralNeeded(payouts, underlyingNeeded, underlyingWeight, minStrike);

        cashCollateralNeeded = getUnderlyingAdjustedCashCollateralNeeded(
            _detail,
            pois,
            payouts,
            cashCollateralNeeded,
            underlyingNeeded
        );

        // consoleG.log("cashCollateralNeeded pre conversion");
        // consoleG.logInt(cashCollateralNeeded);

        // consoleG.log("underlyingNeeded pre conversion");
        // consoleG.logInt(underlyingNeeded);

        if (cashCollateralNeeded > 0 && _detail.underlyingId == _detail.collateralId) {
            cashCollateralNeeded = 0;
            underlyingNeeded = convertCashCollateralToUnderlyingNeeded(_detail, pois, payouts, underlyingNeeded);
        } else
            cashCollateralNeeded = NumberUtil
                .convertDecimals(cashCollateralNeeded.toUint256(), UNIT_DECIMALS, _detail.collateralDecimals)
                .toInt256();

        underlyingNeeded = NumberUtil
            .convertDecimals(underlyingNeeded.toUint256(), UNIT_DECIMALS, _detail.underlyingDecimals)
            .toInt256();

        // consoleG.log("cashCollateralNeeded post conversion");
        // consoleG.logInt(cashCollateralNeeded);

        // consoleG.log("underlyingNeeded post conversion");
        // consoleG.logInt(underlyingNeeded);
    }

    function createPois(
        FullMarginDetailV2 memory _detail,
        uint256[] memory strikes,
        uint256 minStrike,
        uint256 maxStrike
    ) public pure returns (uint256[] memory pois) {
        uint256 epsilon = _detail.spotPrice / 10;

        pois = new uint256[](0);

        if (_detail.putStrikes.length > 0) pois = pois.append(minStrike - epsilon);

        pois = pois.concat(strikes);

        if (_detail.callStrikes.length > 0) pois = pois.append(maxStrike + epsilon);
    }

    function convertPutsToCalls(FullMarginDetailV2 memory _detail)
        public
        pure
        returns (
            uint256[] memory strikes,
            int256[] memory weights,
            int256 underlyingWeight,
            int256 intrinsicValue
        )
    {
        if (_detail.putWeights.length != _detail.putStrikes.length) revert FMMV2_InvalidPutLengths();
        if (_detail.callWeights.length != _detail.callStrikes.length) revert FMMV2_InvalidCallLengths();

        strikes = _detail.putStrikes.concat(_detail.callStrikes);

        int256[] memory synthCallWeights = new int256[](_detail.putWeights.length);

        synthCallWeights = synthCallWeights.populate(_detail.putWeights, 0);

        weights = synthCallWeights.concat(_detail.callWeights);

        // sorting strikes
        uint256[] memory indexes;
        (strikes, indexes) = strikes.argSort();

        // sorting weights based on strike sorted index
        weights = weights.sortByIndexes(indexes);

        underlyingWeight = -_detail.putWeights.sum();

        intrinsicValue = _detail.putStrikes.subEachFrom(_detail.spotPrice).maximum(0).dot(_detail.putWeights) / sUNIT;

        intrinsicValue = -intrinsicValue;
    }

    function calculatePayouts(PayoutsParams memory params) public pure returns (int256[] memory payouts) {
        payouts = new int256[](params.pois.length);
        payouts.fill(0);

        for (uint256 i = 0; i < params.strikes.length; i++) {
            payouts = payouts.add(
                params.pois.subEachBy(params.strikes[i]).maximum(0).mulEachBy(params.weights[i]).divEachBy(sUNIT)
            );
        }

        payouts = payouts
            .add(params.pois.subEachBy(params.spotPrice).mulEachBy(params.underlyingWeight).divEachBy(sUNIT))
            .addEachBy(params.intrinsicValue);
    }

    function calcSlope(int256[] memory leftPoint, int256[] memory rightPoint) public pure returns (int256) {
        if (leftPoint[0] > rightPoint[0]) revert FMMV2_BadPoints();
        if (leftPoint.length != 2) revert FMMV2_InvalidLeftPointLength();
        if (leftPoint.length != rightPoint.length) revert FMMV2_InvalidRightPointLength();

        return (((rightPoint[1] - leftPoint[1]) * sUNIT) / ((rightPoint[0] - leftPoint[0]) * sUNIT)) * sUNIT;
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function getUnderlyingNeeded(uint256[] memory pois, int256[] memory payouts)
        public
        pure
        returns (int256 underlyingNeeded)
    {
        int256[] memory leftPoint = new int256[](2);
        leftPoint[0] = pois.at(-2).toInt256();
        leftPoint[1] = payouts.at(-2);

        int256[] memory rightPoint = new int256[](2);
        rightPoint[0] = pois.at(-1).toInt256();
        rightPoint[1] = payouts.at(-1);

        // slope
        underlyingNeeded = calcSlope(leftPoint, rightPoint);
        underlyingNeeded = underlyingNeeded < sZERO ? -underlyingNeeded : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function getCashCollateralNeeded(
        int256[] memory payouts,
        int256 underlyingNeeded,
        int256 underlyingWeight,
        uint256 minStrike
    ) public pure returns (int256 cashCollateralNeeded) {
        cashCollateralNeeded = underlyingNeeded + underlyingWeight;

        cashCollateralNeeded = ((minStrike.toInt256() * cashCollateralNeeded) / sUNIT) - payouts[1];

        if (cashCollateralNeeded < sZERO) cashCollateralNeeded = sZERO;
    }

    function getUnderlyingAdjustedCashCollateralNeeded(
        FullMarginDetailV2 memory _detail,
        uint256[] memory pois,
        int256[] memory payouts,
        int256 cashCollateralNeeded,
        int256 underlyingNeeded
    ) public pure returns (int256) {
        (int256 startPos, int256 endPos) = getStrikesStartAndEndPos(_detail);

        int256 minStrikePayout = -payouts.slice(startPos, endPos).min();

        if (cashCollateralNeeded < minStrikePayout) {
            (, uint256 index) = payouts.indexOf(-minStrikePayout);
            int256 underlyingPayoutAtMinStrike = (pois[index].toInt256() * underlyingNeeded) / sUNIT;

            if (underlyingPayoutAtMinStrike - minStrikePayout > 0) cashCollateralNeeded = 0;
            else cashCollateralNeeded = minStrikePayout - underlyingPayoutAtMinStrike;
        }

        return cashCollateralNeeded;
    }

    function getStrikesStartAndEndPos(FullMarginDetailV2 memory _detail)
        public
        pure
        returns (int256 startPos, int256 endPos)
    {
        endPos = (_detail.putStrikes.length + _detail.callStrikes.length).toInt256();

        if (_detail.putStrikes.length > 0) {
            startPos = 1;
            endPos += 1;
        }
    }

    function convertCashCollateralToUnderlyingNeeded(
        FullMarginDetailV2 memory _detail,
        uint256[] memory pois,
        int256[] memory payouts,
        int256 underlyingNeeded
    ) public pure returns (int256) {
        (int256 startPos, int256 endPos) = getStrikesStartAndEndPos(_detail);
        uint256 start = startPos.toUint256();
        uint256 end = endPos.toUint256();

        int256[] memory underlyingNeededAtStrikes = new int256[](end - start);

        uint256 y;
        for (uint256 i = start; i < end; ) {
            int256 strike = pois[i].toInt256();
            int256 payout = payouts[i];

            payout = payout < 0 ? -payout : sZERO;

            underlyingNeededAtStrikes[y] = (payout * sUNIT) / strike;

            unchecked {
                y++;
                i++;
            }
        }

        int256 max = underlyingNeededAtStrikes.max();

        return max > underlyingNeeded ? max : underlyingNeeded;
    }
}
