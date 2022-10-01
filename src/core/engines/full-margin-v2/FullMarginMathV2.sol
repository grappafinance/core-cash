// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {TokensUtil} from "../../../libraries/TokensUtil.sol";
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
    using TokensUtil for uint256[];

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return collateralNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(FullMarginDetailV2 memory _detail)
        internal
        view
        returns (int256 collateralNeeded, int256 underlyingNeeded)
    {
        uint256 epsilon = _detail.spotPrice / 10;

        console.log("epsilon", epsilon);

        // underlying price scenarios
        uint256[] memory priceScenarios = new uint256[](0);

        uint256 maxCallStrike = _detail.callStrikes.max();
        uint256 minPutStrike = _detail.putStrikes.min();

        priceScenarios = priceScenarios.add(minPutStrike - epsilon);
        priceScenarios = priceScenarios.concat(_detail.putStrikes);
        priceScenarios = priceScenarios.concat(_detail.callStrikes);
        priceScenarios = priceScenarios.add(maxCallStrike + epsilon);

        int256[] memory payouts = getPayouts(_detail, priceScenarios);

        console.log("payouts");
        console.log(payouts);

        underlyingNeeded = getUnderlyingNeeded(priceScenarios, payouts, maxCallStrike, epsilon);

        console.log("underlyingNeeded");
        console.logInt(underlyingNeeded);

        collateralNeeded = getCollateralNeeded(priceScenarios, payouts, minPutStrike, epsilon, _detail.spotPrice);

        console.log("collateralNeeded");
        console.logInt(collateralNeeded);

        int256 minStrikePayout = -payouts.slice(1, -1).min();

        console.log("minStrikePayout");
        console.logInt(minStrikePayout);

        if (collateralNeeded < minStrikePayout) {
            (, uint256 index) = payouts.indexOf(-minStrikePayout);
            int256 underlyingPayoutAtMinStrike = (priceScenarios[index].toInt256() * underlyingNeeded) / sUNIT;

            console.log("underlyingPayoutAtMinStrike");
            console.logInt(underlyingPayoutAtMinStrike);

            if (underlyingPayoutAtMinStrike - minStrikePayout > 0) {
                collateralNeeded = 0;
            } else {
                collateralNeeded = minStrikePayout - underlyingPayoutAtMinStrike;
            }

            console.log("collateralNeeded");
            console.logInt(collateralNeeded);
        }

        return (collateralNeeded, underlyingNeeded);
    }

    function getPayouts(FullMarginDetailV2 memory _detail, uint256[] memory priceScenarios)
        internal
        view
        returns (int256[] memory payouts)
    {
        payouts = new int256[](priceScenarios.length);
        payouts.fill(0);

        uint256 i;
        for (i = 0; i < _detail.putStrikes.length; i++) {
            payouts = payouts.add(
                priceScenarios
                    .subEachPosFrom(_detail.putStrikes[i])
                    .maximum(0)
                    .mulEachPosBy(_detail.putWeights[i])
                    .divEachPosBy(sUNIT)
            );
        }

        for (i = 0; i < _detail.callStrikes.length; i++) {
            payouts = payouts.add(
                priceScenarios
                    .subEachPosBy(_detail.callStrikes[i])
                    .maximum(0)
                    .mulEachPosBy(_detail.callWeights[i])
                    .divEachPosBy(sUNIT)
            );
        }
    }

    // this the largest loss from all the actual strikes
    function getMaxLossBetweenStrikes(
        uint256[] memory putStrikes,
        uint256[] memory callStrikes,
        uint256[] memory priceScenarios,
        int256[] memory payouts
    ) internal view returns (int256 minStrike) {
        // uint256[] memory strikes = payouts.slice(1, -1).min();
        // console.log(strikes);
        // for
        // minimum_k = -np.min(np.array([payouts[xs==k] for k in put_strikes + call_strikes]).flatten())
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function getUnderlyingNeeded(
        uint256[] memory priceScenarios,
        int256[] memory payouts,
        uint256 maxCallStrike,
        uint256 epsilon
    ) internal pure returns (int256 underlyingNeeded) {
        int256 rightMostPayoutScenario = payouts.at(-1); // we placed it here

        (, uint256 index) = priceScenarios.indexOf(maxCallStrike);
        int256 rightMostPayoutActual = payouts[index];

        underlyingNeeded = ((rightMostPayoutScenario - rightMostPayoutActual) * sUNIT) / epsilon.toInt256();
        underlyingNeeded = underlyingNeeded < sZERO ? -underlyingNeeded : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function getCollateralNeeded(
        uint256[] memory priceScenarios,
        int256[] memory payouts,
        uint256 minPutStrike,
        uint256 epsilon,
        uint256 spotPrice
    ) internal pure returns (int256 collateralNeeded) {
        int256 leftMostPayoutScenario = payouts[0]; // we placed it here

        (, uint256 index) = priceScenarios.indexOf(minPutStrike);
        int256 leftMostPayoutActual = payouts[index];

        collateralNeeded = (leftMostPayoutActual - leftMostPayoutScenario) / epsilon.toInt256();
        collateralNeeded = collateralNeeded * spotPrice.toInt256();
    }
}
