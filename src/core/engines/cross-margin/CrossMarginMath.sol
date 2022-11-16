// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/errors.sol";

/**
 * @title   CrossMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given simple margin account
 */
library CrossMarginMath {
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];
    using SafeCast for int256;
    using SafeCast for uint256;

    error CM_InvalidPutLengths();

    error CM_InvalidCallLengths();

    error CM_InvalidPutWeight();

    error CM_InvalidCallWeight();

    error CM_InvalidPoints();

    error CM_InvalidLeftPointLength();

    error CM_InvalidRightPointLength();

    /**
     * @notice checks inputs for calculating margin, reverts if bad inputs
     * @param _detail margin details
     */
    function verifyInputs(CrossMarginDetail memory _detail) internal pure {
        if (_detail.callStrikes.length != _detail.callWeights.length) revert CM_InvalidCallLengths();
        if (_detail.putStrikes.length != _detail.putWeights.length) revert CM_InvalidPutLengths();

        uint256 i;
        for (i; i < _detail.putWeights.length; ) {
            if (_detail.putWeights[i] == sZERO) revert CM_InvalidPutWeight();

            unchecked {
                ++i;
            }
        }

        for (i = 0; i < _detail.callWeights.length; ) {
            if (_detail.callWeights[i] == sZERO) revert CM_InvalidCallWeight();

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return cashNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(CrossMarginDetail memory _detail)
        external
        pure
        returns (int256 cashNeeded, int256 underlyingNeeded)
    {
        verifyInputs(_detail);

        (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        ) = baseSetup(_detail);

        (cashNeeded, underlyingNeeded) = calcCollateralNeeds(_detail, pois, payouts);

        if (cashNeeded > 0 && _detail.underlyingId == _detail.collateralId) {
            cashNeeded = 0;
            // underlyingNeeded = convertCashCollateralToUnderlyingNeeded(
            //     pois,
            //     payouts,
            //     underlyingNeeded,
            //     _detail.putStrikes.length > 0
            // );
            (, underlyingNeeded) = checkHedgableTailRisk(
                _detail,
                pois,
                payouts,
                strikes,
                syntheticUnderlyingWeight,
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
    }

    function calcCollateralNeeds(
        CrossMarginDetail memory _detail,
        uint256[] memory pois,
        int256[] memory payouts
    ) private pure returns (int256 cashNeeded, int256 underlyingNeeded) {
        bool hasCalls = _detail.callStrikes.length > 0;
        bool hasPuts = _detail.putStrikes.length > 0;

        if (hasCalls) (underlyingNeeded, ) = getUnderlyingNeeded(pois, payouts);

        if (hasPuts) cashNeeded = getCashNeeded(_detail.putStrikes, _detail.putWeights);

        cashNeeded = getUnderlyingAdjustedCashNeeded(pois, payouts, cashNeeded, underlyingNeeded, hasPuts);

        // Not including this until partial collateralization enabled
        // (inUnderlyingOnly, underlyingOnlyNeeded) = checkHedgableTailRisk(
        //     _detail,
        //     pois, payouts,
        //     strikes,
        //     syntheticUnderlyingWeight,
        //     underlyingNeeded,
        //     hasPuts
        // );
    }

    function baseSetup(CrossMarginDetail memory _detail)
        private
        pure
        returns (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        )
    {
        int256 intrinsicValue;
        int256[] memory weights;

        (strikes, weights, syntheticUnderlyingWeight, intrinsicValue) = convertPutsToCalls(_detail);

        pois = createPois(strikes, _detail.putStrikes.length);

        payouts = calcPayouts(pois, strikes, weights, syntheticUnderlyingWeight, _detail.spotPrice, intrinsicValue);
    }

    function createPois(uint256[] memory strikes, uint256 numOfPuts) private pure returns (uint256[] memory pois) {
        uint256 epsilon = strikes.min() / 10;

        bool hasPuts = numOfPuts > 0;

        // left of left-most + strikes + right of right-most
        uint256 poiCount = (hasPuts ? 1 : 0) + strikes.length + 1;

        pois = new uint256[](poiCount);

        if (hasPuts) pois[0] = strikes.min() - epsilon;

        for (uint256 i; i < strikes.length; ) {
            uint256 offset = hasPuts ? 1 : 0;

            pois[i + offset] = strikes[i];

            unchecked {
                ++i;
            }
        }

        pois[pois.length - 1] = strikes.max() + epsilon;
    }

    function convertPutsToCalls(CrossMarginDetail memory _detail)
        private
        pure
        returns (
            uint256[] memory strikes,
            int256[] memory weights,
            int256 syntheticUnderlyingWeight,
            int256 intrinsicValue
        )
    {
        strikes = _detail.putStrikes.concat(_detail.callStrikes);
        weights = _detail.putWeights.concat(_detail.callWeights);

        // sorting strikes
        uint256[] memory indexes;
        (strikes, indexes) = strikes.argSort();

        // sorting weights based on strike sorted index
        weights = weights.sortByIndexes(indexes);

        syntheticUnderlyingWeight = -_detail.putWeights.sum();

        intrinsicValue = _detail.putStrikes.subEachFrom(_detail.spotPrice).maximum(0).dot(_detail.putWeights) / sUNIT;

        intrinsicValue = -intrinsicValue;
    }

    function calcPayouts(
        uint256[] memory pois,
        uint256[] memory strikes,
        int256[] memory weights,
        int256 syntheticUnderlyingWeight,
        uint256 spotPrice,
        int256 intrinsicValue
    ) private pure returns (int256[] memory payouts) {
        payouts = new int256[](pois.length);

        for (uint256 i; i < strikes.length; ) {
            payouts = payouts.add(pois.subEachBy(strikes[i]).maximum(0).eachMulDivDown(weights[i], sUNIT));

            unchecked {
                ++i;
            }
        }

        payouts = payouts.add(pois.subEachBy(spotPrice).eachMulDivDown(syntheticUnderlyingWeight, sUNIT)).addEachBy(
            intrinsicValue
        );
    }

    function calcPutPayouts(uint256[] memory strikes, int256[] memory weights)
        private
        pure
        returns (int256[] memory putPayouts)
    {
        putPayouts = new int256[](strikes.length);

        for (uint256 i; i < strikes.length; ) {
            putPayouts = putPayouts.add(strikes.subEachFrom(strikes[i]).maximum(0).eachMul(weights[i]));

            unchecked {
                ++i;
            }
        }
    }

    function calcSlope(int256[] memory leftPoint, int256[] memory rightPoint) private pure returns (int256) {
        if (leftPoint[0] > rightPoint[0]) revert CM_InvalidPoints();
        if (leftPoint.length != 2) revert CM_InvalidLeftPointLength();
        if (leftPoint.length != 2) revert CM_InvalidRightPointLength();

        return (((rightPoint[1] - leftPoint[1]) * sUNIT) / (rightPoint[0] - leftPoint[0]));
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function getUnderlyingNeeded(uint256[] memory pois, int256[] memory payouts)
        private
        pure
        returns (int256 underlyingNeeded, int256 rightDelta)
    {
        int256[] memory leftPoint = new int256[](2);
        leftPoint[0] = pois.at(-2).toInt256();
        leftPoint[1] = payouts.at(-2);

        int256[] memory rightPoint = new int256[](2);
        rightPoint[0] = pois.at(-1).toInt256();
        rightPoint[1] = payouts.at(-1);

        // slope
        rightDelta = calcSlope(leftPoint, rightPoint);
        underlyingNeeded = rightDelta < sZERO ? -rightDelta : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function getCashNeeded(uint256[] memory putStrikes, int256[] memory putWeights)
        private
        pure
        returns (int256 cashNeeded)
    {
        cashNeeded = -putStrikes.dot(putWeights) / sUNIT;

        if (cashNeeded < sZERO) cashNeeded = sZERO;
    }

    function getUnderlyingAdjustedCashNeeded(
        uint256[] memory pois,
        int256[] memory payouts,
        int256 cashNeeded,
        int256 underlyingNeeded,
        bool hasPuts
    ) private pure returns (int256) {
        int256 minStrikePayout = -payouts.slice(hasPuts ? int256(1) : sZERO, -1).min();

        if (cashNeeded < minStrikePayout) {
            (, uint256 index) = payouts.indexOf(-minStrikePayout);
            int256 underlyingPayoutAtMinStrike = (pois[index].toInt256() * underlyingNeeded) / sUNIT;

            if (underlyingPayoutAtMinStrike - minStrikePayout > 0) cashNeeded = 0;
            else cashNeeded = minStrikePayout - underlyingPayoutAtMinStrike;
        }

        return cashNeeded;
    }

    // Not Currently Used
    // function convertCashCollateralToUnderlyingNeeded(
    //     uint256[] memory pois,
    //     int256[] memory payouts,
    //     int256 underlyingNeeded,
    //     bool hasPuts
    // ) private pure returns (int256) {
    //     uint256 start = hasPuts ? 1 : 0;
    //     // could have used payouts as well
    //     uint256 end = pois.length - 1;

    //     int256[] memory underlyingNeededAtStrikes = new int256[](end - start);

    //     uint256 y;
    //     for (uint256 i = start; i < end; ) {
    //         int256 strike = pois[i].toInt256();
    //         int256 payout = payouts[i];

    //         payout = payout < 0 ? -payout : sZERO;

    //         underlyingNeededAtStrikes[y] = (payout * sUNIT) / strike;

    //         unchecked {
    //             ++y;
    //             ++i;
    //         }
    //     }

    //     int256 max = underlyingNeededAtStrikes.max();

    //     return max > underlyingNeeded ? max : underlyingNeeded;
    // }

    function checkHedgableTailRisk(
        CrossMarginDetail memory _detail,
        uint256[] memory pois,
        int256[] memory payouts,
        uint256[] memory strikes,
        int256 syntheticUnderlyingWeight,
        int256 underlyingNeeded,
        bool hasPuts
    ) public pure returns (bool inUnderlyingOnly, int256 underlyingOnlyNeeded) {
        int256 minPutPayout;
        uint256 startPos = hasPuts ? 1 : 0;

        if (_detail.putStrikes.length > 0) minPutPayout = calcPutPayouts(_detail.putStrikes, _detail.putWeights).min();

        int256 valueAtFirstStrike;

        if (hasPuts) valueAtFirstStrike = -syntheticUnderlyingWeight * int256(strikes[0]) + payouts[startPos];

        inUnderlyingOnly = valueAtFirstStrike + minPutPayout >= sZERO;

        if (inUnderlyingOnly) {
            // shifting pois if there is a left of leftmost, removing right of rightmost, adding underlyingNeeded at the end
            int256[] memory negPayoutsOverPois = new int256[](pois.length - startPos - 1 + 1);

            for (uint256 i = startPos; i < pois.length - 1; ) {
                negPayoutsOverPois[i - startPos] = (-payouts[i] * sUNIT) / int256(pois[i]);

                unchecked {
                    ++i;
                }
            }
            negPayoutsOverPois[negPayoutsOverPois.length - 1] = underlyingNeeded;

            underlyingOnlyNeeded = negPayoutsOverPois.max();
        }
    }
}
