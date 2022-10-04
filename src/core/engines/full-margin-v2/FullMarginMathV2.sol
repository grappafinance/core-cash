// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
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
    using FixedPointMathLib for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return cashCollateralNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(FullMarginDetailV2 memory _detail)
        internal
        pure
        returns (int256 cashCollateralNeeded, int256 underlyingNeeded)
    {
        // TODO: requires weights and strikes are the same

        uint256 epsilon = _detail.spotPrice / 10;

        // underlying price scenarios
        uint256[] memory pricePois = new uint256[](0);

        uint256 minPutStrike;
        uint256 maxCallStrike;

        if (_detail.putStrikes.length > 0) {
            minPutStrike = _detail.putStrikes.min();
            pricePois = pricePois.append(minPutStrike - epsilon);
            pricePois = pricePois.concat(_detail.putStrikes);
        }

        if (_detail.callStrikes.length > 0) {
            maxCallStrike = _detail.callStrikes.max();
            pricePois = pricePois.concat(_detail.callStrikes);
            pricePois = pricePois.append(maxCallStrike + epsilon);
        }

        int256[] memory payouts = getPayouts(_detail, pricePois);

        if (_detail.callStrikes.length > 0)
            underlyingNeeded = getUnderlyingNeeded(pricePois, payouts, maxCallStrike, epsilon);

        if (_detail.putStrikes.length > 0) {
            cashCollateralNeeded = getCashCollateralNeeded(pricePois, payouts, minPutStrike, epsilon);

            cashCollateralNeeded = getUnderlyingAdjustedCashCollateralNeeded(
                _detail,
                pricePois,
                payouts,
                cashCollateralNeeded,
                underlyingNeeded
            );
        }

        return (
            NumberUtil
                .convertDecimals(cashCollateralNeeded.toUint256(), UNIT_DECIMALS, _detail.collateralDecimals)
                .toInt256(),
            NumberUtil
                .convertDecimals(underlyingNeeded.toUint256(), UNIT_DECIMALS, _detail.underlyingDecimals)
                .toInt256()
        );
    }

    function getPayouts(FullMarginDetailV2 memory _detail, uint256[] memory pricePois)
        internal
        pure
        returns (int256[] memory payouts)
    {
        payouts = new int256[](pricePois.length);
        payouts.fill(0);

        uint256 i;
        for (i = 0; i < _detail.putStrikes.length; i++) {
            payouts = payouts.add(
                pricePois
                    .subEachPosFrom(_detail.putStrikes[i])
                    .maximum(0)
                    .mulEachPosBy(_detail.putWeights[i])
                    .divEachPosBy(sUNIT)
            );
        }

        for (i = 0; i < _detail.callStrikes.length; i++) {
            payouts = payouts.add(
                pricePois
                    .subEachPosBy(_detail.callStrikes[i])
                    .maximum(0)
                    .mulEachPosBy(_detail.callWeights[i])
                    .divEachPosBy(sUNIT)
            );
        }
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function getUnderlyingNeeded(
        uint256[] memory pricePois,
        int256[] memory payouts,
        uint256 maxCallStrike,
        uint256 epsilon
    ) internal pure returns (int256 underlyingNeeded) {
        int256 rightMostPayoutScenario = payouts.at(-1); // we placed it here

        (, uint256 index) = pricePois.indexOf(maxCallStrike);
        int256 rightMostPayoutActual = payouts[index];

        underlyingNeeded = ((rightMostPayoutScenario - rightMostPayoutActual) * sUNIT) / epsilon.toInt256();
        underlyingNeeded = underlyingNeeded < sZERO ? -underlyingNeeded : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function getCashCollateralNeeded(
        uint256[] memory pricePois,
        int256[] memory payouts,
        uint256 minPutStrike,
        uint256 epsilon
    ) internal pure returns (int256 cashCollateralNeeded) {
        int256 leftMostPayoutScenario = payouts[0]; // we placed it here

        (, uint256 index) = pricePois.indexOf(minPutStrike);
        int256 leftMostPayoutActual = payouts[index];

        cashCollateralNeeded = ((leftMostPayoutActual - leftMostPayoutScenario) * sUNIT) / epsilon.toInt256();
        cashCollateralNeeded = (cashCollateralNeeded * minPutStrike.toInt256()) / sUNIT;
    }

    function getUnderlyingAdjustedCashCollateralNeeded(
        FullMarginDetailV2 memory _detail,
        uint256[] memory pricePois,
        int256[] memory payouts,
        int256 cashCollateralNeeded,
        int256 underlyingNeeded
    ) internal pure returns (int256) {
        int256 putsStartPos = sZERO;
        int256 callsEndPos = (_detail.putStrikes.length + _detail.callStrikes.length).toInt256();

        if (_detail.putStrikes.length > 0) {
            putsStartPos = 1;
            callsEndPos += 1;
        }

        int256 minStrikePayout = -payouts.slice(putsStartPos, callsEndPos).min();

        if (cashCollateralNeeded < minStrikePayout) {
            (, uint256 index) = payouts.indexOf(-minStrikePayout);
            int256 underlyingPayoutAtMinStrike = (pricePois[index].toInt256() * underlyingNeeded) / sUNIT;

            if (underlyingPayoutAtMinStrike - minStrikePayout > 0) cashCollateralNeeded = 0;
            else cashCollateralNeeded = minStrikePayout - underlyingPayoutAtMinStrike;
        }

        return cashCollateralNeeded;
    }
}
