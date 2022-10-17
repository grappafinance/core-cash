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
        int256 syntheticUnderlyingWeight;
        uint256 spotPrice;
        int256 intrinsicValue;
    }

    struct PoisAndPayouts {
        uint256[] pois;
        int256[] payouts;
    }

    error FMMV2_InvalidPutLengths();

    error FMMV2_InvalidCallLengths();

    error FMMV2_BadPoints();

    error FMMV2_InvalidLeftPointLength();

    error FMMV2_InvalidRightPointLength();

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return cashNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(FullMarginDetailV2 memory _detail)
        public
        view
        returns (int256 cashNeeded, int256 underlyingNeeded)
    {
        (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        ) = baseSetup(_detail);

        PoisAndPayouts memory poisAndPayouts = PoisAndPayouts(pois, payouts);

        (cashNeeded, underlyingNeeded) = calcCollateralNeeds(
            _detail,
            poisAndPayouts,
            syntheticUnderlyingWeight,
            strikes
        );

        if (cashNeeded > 0 && _detail.underlyingId == _detail.collateralId) {
            cashNeeded = 0;
            underlyingNeeded = convertCashCollateralToUnderlyingNeeded(
                poisAndPayouts,
                underlyingNeeded,
                _detail.putStrikes.length > 0
            );
        } else
            cashNeeded = NumberUtil
                .convertDecimals(cashNeeded.toUint256(), UNIT_DECIMALS, _detail.collateralDecimals)
                .toInt256();

        underlyingNeeded = NumberUtil
            .convertDecimals(underlyingNeeded.toUint256(), UNIT_DECIMALS, _detail.underlyingDecimals)
            .toInt256();

        // consoleG.log("cashNeeded post conversion");
        // consoleG.logInt(cashNeeded);

        // consoleG.log("underlyingNeeded post conversion");
        // consoleG.logInt(underlyingNeeded);
    }

    function calcCollateralNeeds(
        FullMarginDetailV2 memory _detail,
        PoisAndPayouts memory poisAndPayouts,
        int256 syntheticUnderlyingWeight,
        uint256[] memory strikes
    ) public view returns (int256 cashNeeded, int256 underlyingNeeded) {
        int256 leftDelta;
        bool hasCalls = _detail.callStrikes.length > 0;
        bool hasPuts = _detail.putStrikes.length > 0;

        if (hasCalls) (underlyingNeeded, ) = getUnderlyingNeeded(poisAndPayouts);

        leftDelta = underlyingNeeded + syntheticUnderlyingWeight;

        if (hasPuts) cashNeeded = getCashNeeded(poisAndPayouts.payouts, leftDelta, strikes.min());

        cashNeeded = getUnderlyingAdjustedCashNeeded(poisAndPayouts, cashNeeded, underlyingNeeded, hasPuts);

        // Not including this until partial collateralization enabled
        // (inUnderlyingOnly, underlyingOnlyNeeded) = checkHedgableTailRisk(
        //     _detail,
        //     poisAndPayouts,
        //     strikes,
        //     syntheticUnderlyingWeight,
        //     underlyingNeeded,
        //     hasPuts
        // );
    }

    function checkHedgableTailRisk(
        FullMarginDetailV2 memory _detail,
        PoisAndPayouts memory poisAndPayouts,
        uint256[] memory strikes,
        int256 syntheticUnderlyingWeight,
        int256 underlyingNeeded,
        bool hasPuts
    ) public view returns (bool inUnderlyingOnly, int256 underlyingOnlyNeeded) {
        int256 minPutPayout;
        uint256 startPos = hasPuts ? 1 : 0;

        if (_detail.putStrikes.length > 0) minPutPayout = calcPutPayouts(_detail.putStrikes, _detail.putWeights).min();

        int256 valueAtFirstStrike;

        if (hasPuts)
            valueAtFirstStrike = -syntheticUnderlyingWeight * int256(strikes[0]) + poisAndPayouts.payouts[startPos];

        inUnderlyingOnly = valueAtFirstStrike + minPutPayout >= sZERO;

        if (inUnderlyingOnly) {
            // shifting pois if there is a left of leftmost, removing right of rightmost, adding underlyingNeeded at the end
            int256[] memory negPayoutsOverPois = new int256[](poisAndPayouts.pois.length - startPos - 1 + 1);

            for (uint256 i = startPos; i < poisAndPayouts.pois.length - 1; ) {
                negPayoutsOverPois[i - startPos] =
                    (-poisAndPayouts.payouts[i] * sUNIT) /
                    int256(poisAndPayouts.pois[i]);

                unchecked {
                    i++;
                }
            }
            negPayoutsOverPois[negPayoutsOverPois.length - 1] = underlyingNeeded;

            underlyingOnlyNeeded = negPayoutsOverPois.max();
        }
    }

    function baseSetup(FullMarginDetailV2 memory _detail)
        public
        view
        returns (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        )
    {
        int256[] memory weights;
        int256 intrinsicValue;

        (strikes, weights, syntheticUnderlyingWeight, intrinsicValue) = convertPutsToCalls(_detail);

        // consoleG.log("strikes");
        // consoleG.log(strikes);

        // consoleG.log("weights");
        // consoleG.log(weights);

        pois = createPois(_detail.putStrikes, strikes, _detail.spotPrice);

        payouts = calcPayouts(
            PayoutsParams(pois, strikes, weights, syntheticUnderlyingWeight, _detail.spotPrice, intrinsicValue)
        );
    }

    function createPois(
        uint256[] memory putStrikes,
        uint256[] memory strikes,
        uint256 spotPrice
    ) public view returns (uint256[] memory pois) {
        uint256 epsilon = spotPrice / 10;

        bool hasPuts = putStrikes.length > 0;

        // left of left-most + strikes + right of right-most
        uint256 poiCount = (hasPuts ? 1 : 0) + strikes.length + 1;

        pois = new uint256[](poiCount);

        if (putStrikes.length > 0) pois[0] = strikes.min() - epsilon;

        for (uint256 i; i < strikes.length; ) {
            uint256 offset = hasPuts ? 1 : 0;

            pois[i + offset] = strikes[i];

            unchecked {
                i++;
            }
        }

        pois[pois.length - 1] = strikes.max() + epsilon;
    }

    function convertPutsToCalls(FullMarginDetailV2 memory _detail)
        public
        pure
        returns (
            uint256[] memory strikes,
            int256[] memory weights,
            int256 syntheticUnderlyingWeight,
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

        syntheticUnderlyingWeight = -_detail.putWeights.sum();

        intrinsicValue = _detail.putStrikes.subEachFrom(_detail.spotPrice).maximum(0).dot(_detail.putWeights) / sUNIT;

        intrinsicValue = -intrinsicValue;
    }

    function calcPayouts(PayoutsParams memory params) public pure returns (int256[] memory payouts) {
        payouts = new int256[](params.pois.length);

        for (uint256 i; i < params.strikes.length; ) {
            payouts = payouts.add(
                params.pois.subEachBy(params.strikes[i]).maximum(0).mulEachBy(params.weights[i]).divEachBy(sUNIT)
            );

            unchecked {
                i++;
            }
        }

        payouts = payouts
            .add(params.pois.subEachBy(params.spotPrice).mulEachBy(params.syntheticUnderlyingWeight).divEachBy(sUNIT))
            .addEachBy(params.intrinsicValue);
    }

    function calcPutPayouts(uint256[] memory strikes, int256[] memory weights)
        public
        view
        returns (int256[] memory putPayouts)
    {
        putPayouts = new int256[](strikes.length);

        for (uint256 i; i < strikes.length; ) {
            putPayouts = putPayouts.add(strikes.subEachFrom(strikes[i]).maximum(0).mulEachBy(weights[i]));

            unchecked {
                i++;
            }
        }
    }

    function calcSlope(int256[] memory leftPoint, int256[] memory rightPoint) public pure returns (int256) {
        if (leftPoint[0] > rightPoint[0]) revert FMMV2_BadPoints();
        if (leftPoint.length != 2) revert FMMV2_InvalidLeftPointLength();
        if (leftPoint.length != rightPoint.length) revert FMMV2_InvalidRightPointLength();

        return (((rightPoint[1] - leftPoint[1]) * sUNIT) / (rightPoint[0] - leftPoint[0]));
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function getUnderlyingNeeded(PoisAndPayouts memory poisAndPayouts)
        public
        pure
        returns (int256 underlyingNeeded, int256 rightDelta)
    {
        int256[] memory leftPoint = new int256[](2);
        leftPoint[0] = poisAndPayouts.pois.at(-2).toInt256();
        leftPoint[1] = poisAndPayouts.payouts.at(-2);

        int256[] memory rightPoint = new int256[](2);
        rightPoint[0] = poisAndPayouts.pois.at(-1).toInt256();
        rightPoint[1] = poisAndPayouts.payouts.at(-1);

        // slope
        rightDelta = calcSlope(leftPoint, rightPoint);
        underlyingNeeded = rightDelta < sZERO ? -rightDelta : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function getCashNeeded(
        int256[] memory payouts,
        int256 leftDelta,
        uint256 minStrike
    ) public pure returns (int256 cashNeeded) {
        cashNeeded = ((minStrike.toInt256() * leftDelta) / sUNIT) - payouts[1];

        if (cashNeeded < sZERO) cashNeeded = sZERO;
    }

    function getUnderlyingAdjustedCashNeeded(
        PoisAndPayouts memory poisAndPayouts,
        int256 cashNeeded,
        int256 underlyingNeeded,
        bool hasPuts
    ) public pure returns (int256) {
        int256 minStrikePayout = -poisAndPayouts.payouts.slice(hasPuts ? int256(1) : sZERO, -1).min();

        if (cashNeeded < minStrikePayout) {
            (, uint256 index) = poisAndPayouts.payouts.indexOf(-minStrikePayout);
            int256 underlyingPayoutAtMinStrike = (poisAndPayouts.pois[index].toInt256() * underlyingNeeded) / sUNIT;

            if (underlyingPayoutAtMinStrike - minStrikePayout > 0) cashNeeded = 0;
            else cashNeeded = minStrikePayout - underlyingPayoutAtMinStrike;
        }

        return cashNeeded;
    }

    function getStrikesStartAndEndPos(uint256 putsLength, uint256 callsLength)
        public
        pure
        returns (int256 startPos, int256 endPos)
    {
        endPos = (putsLength + callsLength).toInt256();

        if (putsLength > 0) {
            startPos = 1;
            endPos += 1;
        }
    }

    function convertCashCollateralToUnderlyingNeeded(
        PoisAndPayouts memory poisAndPayouts,
        int256 underlyingNeeded,
        bool hasPuts
    ) public pure returns (int256) {
        uint256 start = hasPuts ? 1 : 0;
        // could have used payouts as well
        uint256 end = poisAndPayouts.pois.length - 1;

        int256[] memory underlyingNeededAtStrikes = new int256[](end - start);

        uint256 y;
        for (uint256 i = start; i < end; ) {
            int256 strike = poisAndPayouts.pois[i].toInt256();
            int256 payout = poisAndPayouts.payouts[i];

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
