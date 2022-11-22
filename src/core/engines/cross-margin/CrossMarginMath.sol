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
 * @notice  this library is in charge of calculating the min collateral for a given cross margin account
 * @dev     deployed as a separate contract to save space
 */
library CrossMarginMath {
    using AccountUtil for Balance[];
    using AccountUtil for CrossMarginDetail[];
    using AccountUtil for Position[];
    using AccountUtil for PositionOptim[];
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

    /**
     * @notice get minimum collateral for a given amount of shorts & longs
     * @dev typically used for calculating a portfolios margin requirements
     * @param grappa interface to query grappa contract
     * @param shorts is array of Position structs
     * @param longs is array of Position structs
     * @return amounts is an array of Balance struct representing full collateralization
     */
    function getMinCollateralForPositions(
        IGrappa grappa,
        Position[] calldata shorts,
        Position[] calldata longs
    ) external view returns (Balance[] memory amounts) {
        // groups shorts and longs by underlying + strike + collateral + expiry
        CrossMarginDetail[] memory details = _getPositionDetails(grappa, shorts, longs);

        // protfilio has no longs or shorts
        if (details.length == 0) return amounts;

        bool found;
        uint256 index;

        for (uint256 i; i < details.length; ) {
            CrossMarginDetail memory detail = details[i];

            // checks that the combination has positions, otherwiser skips
            if (detail.callWeights.length != 0 || detail.putWeights.length != 0) {
                // gets the amount of numeraire and underlying needed
                (uint256 numeraireNeeded, uint256 underlyingNeeded) = getMinCollateral(detail);

                if (numeraireNeeded != 0) {
                    (found, index) = amounts.indexOf(detail.collateralId);

                    if (found) amounts[index].amount += numeraireNeeded.toUint80();
                    else amounts = amounts.append(Balance(detail.collateralId, numeraireNeeded.toUint80()));
                }

                if (underlyingNeeded != 0) {
                    (found, index) = amounts.indexOf(detail.underlyingId);

                    if (found) amounts[index].amount += underlyingNeeded.toUint80();
                    else amounts = amounts.append(Balance(detail.underlyingId, underlyingNeeded.toUint80()));
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
     * @notice get minimum collateral
     * @dev detail is composed of positions with the same underlying + strike + collateral + expiry
     * @param _detail margin details
     * @return numeraireNeeded with {collateral asset's} decimals
     * @return underlyingNeeded with {underlying asset's} decimals
     */
    function getMinCollateral(CrossMarginDetail memory _detail)
        public
        pure
        returns (uint256 numeraireNeeded, uint256 underlyingNeeded)
    {
        _verifyInputs(_detail);

        (
            uint256[] memory strikes,
            int256 syntheticUnderlyingWeight,
            uint256[] memory pois,
            int256[] memory payouts
        ) = _baseSetup(_detail);

        (numeraireNeeded, underlyingNeeded) = _calcCollateralNeeds(
            _detail.putStrikes,
            _detail.putWeights,
            _detail.callStrikes.length > 0,
            pois,
            payouts
        );

        // if options collateralizied in underlying, forcing numeraire to be converted to underlying
        // only applied to calls since puts cannot be collateralized in underlying
        if (numeraireNeeded > 0 && _detail.underlyingId == _detail.collateralId) {
            numeraireNeeded = 0;

            (, underlyingNeeded) = _checkHedgableTailRisk(
                _detail,
                pois,
                payouts,
                strikes,
                syntheticUnderlyingWeight,
                underlyingNeeded,
                _detail.putStrikes.length > 0
            );
        } else {
            numeraireNeeded = NumberUtil.convertDecimals(numeraireNeeded, UNIT_DECIMALS, _detail.collateralDecimals);
        }

        underlyingNeeded = NumberUtil.convertDecimals(underlyingNeeded, UNIT_DECIMALS, _detail.underlyingDecimals);
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

    /**
     * @notice get numeraire and underlying needed to fully collateralize
     * @dev calculates left side and right side of the payout profile
     * @param putStrikes array of put option strikes
     * @param putWeights amount of options at a given strike
     * @param hasCalls has call options
     * @param pois are the strikes we are evaluating
     * @param payouts are the payouts at a given strike
     * @return numeraireNeeded with {collateral asset's} decimals
     * @return underlyingNeeded with {underlying asset's} decimals
     */
    function _calcCollateralNeeds(
        uint256[] memory putStrikes,
        int256[] memory putWeights,
        bool hasCalls,
        uint256[] memory pois,
        int256[] memory payouts
    ) internal pure returns (uint256 numeraireNeeded, uint256 underlyingNeeded) {
        bool hasPuts = putStrikes.length > 0;

        // if call options exist, get amount of underlying needed (right side of payout profile)
        if (hasCalls) (underlyingNeeded, ) = _getUnderlyingNeeded(pois, payouts);

        // if put options exist, get amount of numeraire needed (left side of payout profile)
        if (hasPuts) numeraireNeeded = _getNumeraireNeeded(putStrikes, putWeights);

        // crediting the numeraire if underlying has a positive payout
        numeraireNeeded = _getUnderlyingAdjustedNumeraireNeeded(
            pois,
            payouts,
            numeraireNeeded,
            underlyingNeeded,
            hasPuts
        );
    }

    /**
     * @notice setting up values needed to calculate margin requirements
     * @param _detail margin details
     * @return strikes of shorts and longs
     * @return syntheticUnderlyingWeight sum of put positions (negative)
     * @return pois array of point-of-interests (aka strikes)
     * @return payouts payouts for a given poi position
     */
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

        // using put/call parity to convert puts to calls
        (strikes, weights, syntheticUnderlyingWeight, intrinsicValue) = _convertPutsToCalls(_detail);

        // points-of-interest, array of strikes needed to evaluate collateral requirements
        pois = _createPois(strikes, _detail.putStrikes.length);

        // payouts at each point-of-interest
        payouts = _calcPayouts(pois, strikes, weights, syntheticUnderlyingWeight, _detail.spotPrice, intrinsicValue);
    }

    /**
     * @notice generating points of interest (strikes)
     * @dev adding a point left of left most strike (puts) and a right point of right most strike (call)
     * @param strikes array of shorts and longs
     * @param numOfPuts number of puts
     * @return pois array of point-of-interests (aka strikes)
     */
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

    /**
     * @notice using put/call parity to convert puts to calls
     * @param _detail margin details
     * @return strikes of call options
     * @return weights amount of options for a given strike
     * @return syntheticUnderlyingWeight sum of put positions (negative)
     * @return intrinsicValue of put payouts
     */
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

    /**
     * @notice calculate payouts at each point of interest
     * @param pois array of point-of-interests (aka strikes)
     * @param strikes concatentated array of shorts and longs
     * @param weights number of options at each strike
     * @param syntheticUnderlyingWeight sum of put positions (negative)
     * @param spotPrice current price of underlying given a strike asset
     * @param intrinsicValue of put payouts
     * @return payouts payouts for a given poi position
     */
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

    /**
     * @notice calculate slope
     * @dev used to calculate directionality of the payout profile
     * @param leftPoint coordinates of x,y
     * @param rightPoint coordinates of x,y
     * @return direction positive or negative
     */
    function _calcSlope(int256[] memory leftPoint, int256[] memory rightPoint) internal pure returns (int256) {
        if (leftPoint[0] > rightPoint[0]) revert CM_InvalidPoints();
        if (leftPoint.length != 2) revert CM_InvalidLeftPointLength();
        if (leftPoint.length != 2) revert CM_InvalidRightPointLength();

        return (((rightPoint[1] - leftPoint[1]) * sUNIT) / (rightPoint[0] - leftPoint[0]));
    }

    /**
     * @notice computes the slope to the right of the right most strike (call options), resulting in the delta hedge (underlying)
     * @param pois points of interest (strikes)
     * @param payouts payouts at coorisponding pois
     * @return underlyingNeeded amount of underlying needed
     * @return rightDelta the slope
     */
    function _getUnderlyingNeeded(uint256[] memory pois, int256[] memory payouts)
        internal
        pure
        returns (uint256 underlyingNeeded, int256 rightDelta)
    {
        int256[] memory leftPoint = new int256[](2);
        leftPoint[0] = pois.at(-2).toInt256();
        leftPoint[1] = payouts.at(-2);

        int256[] memory rightPoint = new int256[](2);
        rightPoint[0] = pois.at(-1).toInt256();
        rightPoint[1] = payouts.at(-1);

        // slope
        rightDelta = _calcSlope(leftPoint, rightPoint);
        underlyingNeeded = rightDelta < sZERO ? uint256(-rightDelta) : ZERO;
    }

    /**
     * @notice computes the slope to the left of the left most strike (put options)
     * @dev only called if there are put options, usually denominated in cash
     * @param putStrikes put option strikes
     * @param putWeights number of put options at a coorisponding strike
     * @return numeraireNeeded amount of numeraire asset needed
     */
    function _getNumeraireNeeded(uint256[] memory putStrikes, int256[] memory putWeights)
        internal
        pure
        returns (uint256 numeraireNeeded)
    {
        int256 tmpNumeraireNeeded = putStrikes.dot(putWeights) / sUNIT;

        numeraireNeeded = tmpNumeraireNeeded < sZERO ? uint256(-tmpNumeraireNeeded) : ZERO;
    }

    /**
     * @notice crediting the numeraire if underlying has a positive payout
     * @dev checks if subAccount has positive underlying value, if it does then cash requirements can be lowered
     * @param pois option strikes
     * @param payouts payouts at coorisponding pois
     * @param numeraireNeeded current numeraire needed
     * @param underlyingNeeded underlying needed
     * @param hasPuts has put options
     * @return numeraireNeeded adjusted numerarie needed
     */
    function _getUnderlyingAdjustedNumeraireNeeded(
        uint256[] memory pois,
        int256[] memory payouts,
        uint256 numeraireNeeded,
        uint256 underlyingNeeded,
        bool hasPuts
    ) internal pure returns (uint256) {
        // only evaluate actual strikes (left and right most strikes are evauluating directionality)
        int256 minStrikePayout = -payouts.slice(hasPuts ? int256(1) : sZERO, -1).min();

        if (numeraireNeeded.toInt256() < minStrikePayout) {
            (, uint256 index) = payouts.indexOf(-minStrikePayout);
            uint256 underlyingPayoutAtMinStrike = (pois[index] * underlyingNeeded) / UNIT;

            if (underlyingPayoutAtMinStrike.toInt256() > minStrikePayout) numeraireNeeded = ZERO;
            else numeraireNeeded = uint256(minStrikePayout) - underlyingPayoutAtMinStrike; // check directly above means minStrikePayout > 0
        }

        return numeraireNeeded;
    }

    /**
     * @notice converts numerarie needed entirely in underlying
     * @dev only used if options collateralizied in underlying
     * @param _detail margin details
     * @param pois option strikes
     * @param payouts payouts at coorisponding pois
     * @param strikes option strikes without testing strikes
     * @param syntheticUnderlyingWeight sum of put positions (negative)
     * @param underlyingNeeded current underlying needed
     * @param hasPuts has put options
     * @return inUnderlyingOnly bool if it can be done
     * @return underlyingOnlyNeeded adjusted underlying needed
     */
    function _checkHedgableTailRisk(
        CrossMarginDetail memory _detail,
        uint256[] memory pois,
        int256[] memory payouts,
        uint256[] memory strikes,
        int256 syntheticUnderlyingWeight,
        uint256 underlyingNeeded,
        bool hasPuts
    ) internal pure returns (bool inUnderlyingOnly, uint256 underlyingOnlyNeeded) {
        int256 minPutPayout;
        uint256 startPos = hasPuts ? 1 : 0;

        if (_detail.putStrikes.length > 0) minPutPayout = _calcPutPayouts(_detail.putStrikes, _detail.putWeights).min();

        int256 valueAtFirstStrike;

        if (hasPuts) valueAtFirstStrike = -syntheticUnderlyingWeight * int256(strikes[0]) + payouts[startPos];

        inUnderlyingOnly = valueAtFirstStrike + minPutPayout >= sZERO;

        if (inUnderlyingOnly) {
            // shifting pois if there is a left of leftmost, removing right of rightmost, adding underlyingNeeded at the end
            // ie: pois.length - startPos - 1 + 1
            int256[] memory negPayoutsOverPois = new int256[](pois.length - startPos);

            for (uint256 i = startPos; i < pois.length - 1; ) {
                negPayoutsOverPois[i - startPos] = (-payouts[i] * sUNIT) / int256(pois[i]);

                unchecked {
                    ++i;
                }
            }
            negPayoutsOverPois[negPayoutsOverPois.length - 1] = underlyingNeeded.toInt256();

            int256 tmpUnderlyingOnlyNeeded = negPayoutsOverPois.max();

            underlyingOnlyNeeded = tmpUnderlyingOnlyNeeded > 0 ? uint256(tmpUnderlyingOnlyNeeded) : ZERO;
        }
    }

    /**
     * @notice calculate put option payouts at each point of interest
     * @dev only called if there are put options
     * @param strikes concatentated array of shorts and longs
     * @param weights number of options at each strike
     * @return putPayouts payouts for a put options at a coorisponding strike
     */
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

    /*///////////////////////////////////////////////////////////////
                         Setup CrossMarginDetail
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  converts Position struct arrays to in-memory detail struct arrays
     */
    function _getPositionDetails(
        IGrappa grappa,
        Position[] calldata shorts,
        Position[] calldata longs
    ) internal view returns (CrossMarginDetail[] memory details) {
        details = new CrossMarginDetail[](0);

        // used to reference which detail struct should be updated for a given position
        bytes32[] memory usceLookUp = new bytes32[](0);

        Position[] memory positions = shorts.concat(longs);
        uint256 shortLength = shorts.length;

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

    /**
     * @notice merges option and amounts into the set
     * @dev if weight turns into zero, we remove it from the set
     */
    function _processDetailWithToken(
        CrossMarginDetail memory detail,
        uint256 tokenId,
        int256 amount
    ) internal pure {
        (TokenType tokenType, , , uint64 strike, ) = tokenId.parseTokenId();

        bool found;
        uint256 index;

        // adjust or append to callStrikes array or callWeights array.
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
        } else if (tokenType == TokenType.PUT) {
            // adjust or append to putStrikes array or putWeights array.
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

    /**
     * @notice gets product asset specific details from grappa in one call
     */
    function _getProductDetails(IGrappa grappa, uint40 productId) internal view returns (ProductDetails memory info) {
        (, , uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        (
            address oracle,
            ,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            ,
            ,
            uint8 collatDecimals
        ) = grappa.getDetailFromProductId(productId);

        info.oracle = oracle;
        info.underlying = underlying;
        info.underlyingId = underlyingId;
        info.underlyingDecimals = underlyingDecimals;
        info.strike = strike;
        info.strikeId = strikeId;
        info.collateralId = collateralId;
        info.collateralDecimals = collatDecimals;
    }
}
