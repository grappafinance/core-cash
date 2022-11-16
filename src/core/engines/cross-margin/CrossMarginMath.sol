// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IOracle} from "../../../interfaces/IOracle.sol";

import {AccountUtil} from "../../../libraries/AccountUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";

import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/errors.sol";

/**
 * @title   CrossMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given simple margin account
 */
library CrossMarginMath {
    using AccountUtil for Balance[];
    using AccountUtil for CrossMarginDetail[];
    using AccountUtil for Position[];
    using AccountUtil for PositionOptim[];
    using AccountUtil for SBalance[];
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenIdUtil for uint256;

    error CM_InvalidPutLengths();

    error CM_InvalidCallLengths();

    error CM_InvalidPutWeight();

    error CM_InvalidCallWeight();

    error CM_InvalidPoints();

    error CM_InvalidLeftPointLength();

    error CM_InvalidRightPointLength();

    /*///////////////////////////////////////////////////////////////
                         Portfolio Margin Requirements
    //////////////////////////////////////////////////////////////*/

    function getMinCollateralForAccount(IGrappa grappa, CrossMarginAccount memory account)
        external
        view
        returns (SBalance[] memory balances)
    {
        CrossMarginDetail[] memory details = _getAccountDetails(grappa, account);

        balances = account.collaterals.toSBalances();

        if (details.length == 0) return balances;

        bool found;
        uint256 index;

        for (uint256 i; i < details.length; ) {
            CrossMarginDetail memory detail = details[i];

            if (detail.callWeights.length != 0 || detail.putWeights.length != 0) {
                (int256 cashCollateralNeeded, int256 underlyingNeeded) = getMinCollateral(detail);

                if (cashCollateralNeeded != 0) {
                    (found, index) = balances.indexOf(detail.collateralId);

                    if (found) balances[index].amount -= cashCollateralNeeded.toInt80();
                    else balances = balances.append(SBalance(detail.collateralId, -cashCollateralNeeded.toInt80()));
                }

                if (underlyingNeeded != 0) {
                    (found, index) = balances.indexOf(detail.underlyingId);

                    if (found) balances[index].amount -= underlyingNeeded.toInt80();
                    else balances = balances.append(SBalance(detail.underlyingId, -underlyingNeeded.toInt80()));
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                         Cross Margin Calculations
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _detail margin details
     * @return cashNeeded with {BASE_UNIT} decimals
     * @return underlyingNeeded with {BASE_UNIT} decimals
     */
    function getMinCollateral(CrossMarginDetail memory _detail)
        public
        pure
        returns (int256 cashNeeded, int256 underlyingNeeded)
    {
        _verifyInputs(_detail);

        (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        ) = _baseSetup(_detail);

        (cashNeeded, underlyingNeeded) = _calcCollateralNeeds(_detail, pois, payouts);

        if (cashNeeded > 0 && _detail.underlyingId == _detail.collateralId) {
            cashNeeded = 0;
            // underlyingNeeded = convertCashCollateralToUnderlyingNeeded(
            //     pois,
            //     payouts,
            //     underlyingNeeded,
            //     _detail.putStrikes.length > 0
            // );
            (, underlyingNeeded) = _checkHedgableTailRisk(
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

    /**
     * @notice checks inputs for calculating margin, reverts if bad inputs
     * @param _detail margin details
     */
    function _verifyInputs(CrossMarginDetail memory _detail) internal pure {
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

    function _calcCollateralNeeds(
        CrossMarginDetail memory _detail,
        uint256[] memory pois,
        int256[] memory payouts
    ) internal pure returns (int256 cashNeeded, int256 underlyingNeeded) {
        bool hasCalls = _detail.callStrikes.length > 0;
        bool hasPuts = _detail.putStrikes.length > 0;

        if (hasCalls) (underlyingNeeded, ) = _getUnderlyingNeeded(pois, payouts);

        if (hasPuts) cashNeeded = _getCashNeeded(_detail.putStrikes, _detail.putWeights);

        cashNeeded = _getUnderlyingAdjustedCashNeeded(pois, payouts, cashNeeded, underlyingNeeded, hasPuts);

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

    function _baseSetup(CrossMarginDetail memory _detail)
        internal
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

        (strikes, weights, syntheticUnderlyingWeight, intrinsicValue) = _convertPutsToCalls(_detail);

        pois = _createPois(strikes, _detail.putStrikes.length);

        payouts = _calcPayouts(pois, strikes, weights, syntheticUnderlyingWeight, _detail.spotPrice, intrinsicValue);
    }

    function _createPois(uint256[] memory strikes, uint256 numOfPuts) internal pure returns (uint256[] memory pois) {
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

    function _convertPutsToCalls(CrossMarginDetail memory _detail)
        internal
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

    function _calcPayouts(
        uint256[] memory pois,
        uint256[] memory strikes,
        int256[] memory weights,
        int256 syntheticUnderlyingWeight,
        uint256 spotPrice,
        int256 intrinsicValue
    ) internal pure returns (int256[] memory payouts) {
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

    function _calcPutPayouts(uint256[] memory strikes, int256[] memory weights)
        internal
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

    function _calcSlope(int256[] memory leftPoint, int256[] memory rightPoint) internal pure returns (int256) {
        if (leftPoint[0] > rightPoint[0]) revert CM_InvalidPoints();
        if (leftPoint.length != 2) revert CM_InvalidLeftPointLength();
        if (leftPoint.length != 2) revert CM_InvalidRightPointLength();

        return (((rightPoint[1] - leftPoint[1]) * sUNIT) / (rightPoint[0] - leftPoint[0]));
    }

    // this computes the slope to the right of the right most strike, resulting in the delta hedge (underlying)
    function _getUnderlyingNeeded(uint256[] memory pois, int256[] memory payouts)
        internal
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
        rightDelta = _calcSlope(leftPoint, rightPoint);
        underlyingNeeded = rightDelta < sZERO ? -rightDelta : sZERO;
    }

    // this computes the slope to the left of the left most strike
    function _getCashNeeded(uint256[] memory putStrikes, int256[] memory putWeights)
        internal
        pure
        returns (int256 cashNeeded)
    {
        cashNeeded = -putStrikes.dot(putWeights) / sUNIT;

        if (cashNeeded < sZERO) cashNeeded = sZERO;
    }

    function _getUnderlyingAdjustedCashNeeded(
        uint256[] memory pois,
        int256[] memory payouts,
        int256 cashNeeded,
        int256 underlyingNeeded,
        bool hasPuts
    ) internal pure returns (int256) {
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
    // ) internal pure returns (int256) {
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

    function _checkHedgableTailRisk(
        CrossMarginDetail memory _detail,
        uint256[] memory pois,
        int256[] memory payouts,
        uint256[] memory strikes,
        int256 syntheticUnderlyingWeight,
        int256 underlyingNeeded,
        bool hasPuts
    ) internal pure returns (bool inUnderlyingOnly, int256 underlyingOnlyNeeded) {
        int256 minPutPayout;
        uint256 startPos = hasPuts ? 1 : 0;

        if (_detail.putStrikes.length > 0) minPutPayout = _calcPutPayouts(_detail.putStrikes, _detail.putWeights).min();

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

    /*///////////////////////////////////////////////////////////////
                         Setup CrossMarginDetail
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetails(IGrappa grappa, CrossMarginAccount memory account)
        internal
        view
        returns (CrossMarginDetail[] memory details)
    {
        details = new CrossMarginDetail[](0);

        bytes32[] memory usceLookUp = new bytes32[](0);

        Position[] memory positions = account.shorts.getPositions().concat(account.longs.getPositions());
        uint256 shortLength = account.shorts.length;

        for (uint256 i; i < positions.length; ) {
            (, uint40 productId, uint64 expiry, , ) = positions[i].tokenId.parseTokenId();

            ProductDetails memory product = _getProductDetails(grappa, productId);

            bytes32 pos = keccak256(abi.encode(product.underlyingId, product.strikeId, product.collateralId, expiry));
            (bool found, uint256 index) = ArrayUtil.indexOf(usceLookUp, pos);

            CrossMarginDetail memory detail;

            if (found) detail = details[index];
            else {
                usceLookUp = ArrayUtil.append(usceLookUp, pos);
                details = details.append(detail);

                detail.underlyingId = product.underlyingId;
                detail.underlyingDecimals = product.underlyingDecimals;
                detail.collateralId = product.collateralId;
                detail.collateralDecimals = product.collateralDecimals;
                detail.spotPrice = IOracle(product.oracle).getSpotPrice(product.underlying, product.strike);
                detail.expiry = expiry;
            }

            int256 amount = int256(int64(positions[i].amount));
            if (i < shortLength) amount = -amount;

            _processDetailWithToken(detail, positions[i].tokenId, amount);

            unchecked {
                ++i;
            }
        }
    }

    function _processDetailWithToken(
        CrossMarginDetail memory detail,
        uint256 tokenId,
        int256 amount
    ) internal pure {
        (TokenType tokenType, , , uint64 strike, ) = tokenId.parseTokenId();

        bool found;
        uint256 index;

        if (tokenType == TokenType.CALL) {
            (found, index) = detail.callStrikes.indexOf(strike);

            if (found) {
                detail.callWeights[index] += amount;

                if (detail.callWeights[index] == 0) {
                    detail.callWeights = detail.callWeights.remove(index);
                    detail.callStrikes = detail.callStrikes.remove(index);
                }
            } else {
                detail.callStrikes = detail.callStrikes.append(strike);
                detail.callWeights = detail.callWeights.append(amount);
            }
        }

        if (tokenType == TokenType.PUT) {
            (found, index) = detail.putStrikes.indexOf(strike);

            if (found) {
                detail.putWeights[index] += amount;

                if (detail.putWeights[index] == 0) {
                    detail.putWeights = detail.putWeights.remove(index);
                    detail.putStrikes = detail.putStrikes.remove(index);
                }
            } else {
                detail.putStrikes = detail.putStrikes.append(strike);
                detail.putWeights = detail.putWeights.append(amount);
            }
        }
    }

    function _getProductDetails(IGrappa grappa, uint40 productId) internal view returns (ProductDetails memory info) {
        (, , uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        (
            address oracle,
            address engine,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            uint8 strikeDecimals,
            address collateral,
            uint8 collatDecimals
        ) = grappa.getDetailFromProductId(productId);

        info.oracle = oracle;
        info.engine = engine;
        info.underlying = underlying;
        info.underlyingId = underlyingId;
        info.underlyingDecimals = underlyingDecimals;
        info.strike = strike;
        info.strikeId = strikeId;
        info.strikeDecimals = strikeDecimals;
        info.collateral = collateral;
        info.collateralId = collateralId;
        info.collateralDecimals = collatDecimals;
    }
}
