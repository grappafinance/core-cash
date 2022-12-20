// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IOracle} from "../../../interfaces/IOracle.sol";

// shard libraries
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {BalanceUtil} from "../../../libraries/BalanceUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

// cross margin libraries
import {AccountUtil} from "./AccountUtil.sol";

// Cross margin types
import "./types.sol";

import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/errors.sol";

/**
 * @title   CrossMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given cross margin account
 * @dev     deployed as a separate contract to save space
 */
library CrossMarginMath {
    using BalanceUtil for Balance[];
    using AccountUtil for CrossMarginDetail[];
    using AccountUtil for Position[];
    using AccountUtil for PositionOptim[];
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];
    using SafeCast for int256;
    using SafeCast for uint256;
    using TokenIdUtil for uint256;

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
    function getMinCollateralForPositions(IGrappa grappa, Position[] calldata shorts, Position[] calldata longs)
        external
        view
        returns (Balance[] memory amounts)
    {
        // groups shorts and longs by underlying + strike + collateral + expiry
        CrossMarginDetail[] memory details = _getPositionDetails(grappa, shorts, longs);

        // portfolio has no longs or shorts
        if (details.length == ZERO) return amounts;

        bool found;
        uint256 index;

        for (uint256 i; i < details.length;) {
            CrossMarginDetail memory detail = details[i];

            // checks that the combination has positions, otherwiser skips
            if (detail.callWeights.length != ZERO || detail.putWeights.length != ZERO) {
                // gets the amount of numeraire and underlying needed
                (uint256 numeraireNeeded, uint256 underlyingNeeded) = getMinCollateral(detail);

                if (numeraireNeeded != ZERO) {
                    (found, index) = amounts.indexOf(detail.numeraireId);

                    if (found) amounts[index].amount += numeraireNeeded.toUint80();
                    else amounts = amounts.append(Balance(detail.numeraireId, numeraireNeeded.toUint80()));
                }

                if (underlyingNeeded != ZERO) {
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
     * @dev detail is composed of positions with the same underlying + strike + expiry
     * @param _detail margin details
     * @return numeraireNeeded with {numeraire asset's} decimals
     * @return underlyingNeeded with {underlying asset's} decimals
     */
    function getMinCollateral(CrossMarginDetail memory _detail)
        public
        pure
        returns (uint256 numeraireNeeded, uint256 underlyingNeeded)
    {
        _verifyInputs(_detail);

        (uint256[] memory pois, int256[] memory payouts) = _baseSetup(_detail);

        (numeraireNeeded, underlyingNeeded) = _calcCollateralNeeds(_detail, pois, payouts);

        // if options collateralizied in underlying, forcing numeraire to be converted to underlying
        // only applied to calls since puts cannot be collateralized in underlying
        if (numeraireNeeded > ZERO && _detail.putStrikes.length == ZERO) {
            numeraireNeeded = ZERO;

            underlyingNeeded = _convertCallCollateralToUnderlying(pois, payouts, underlyingNeeded);
        } else {
            numeraireNeeded = NumberUtil.convertDecimals(numeraireNeeded, UNIT_DECIMALS, _detail.numeraireDecimals);
        }

        underlyingNeeded = NumberUtil.convertDecimals(underlyingNeeded, UNIT_DECIMALS, _detail.underlyingDecimals);
    }

    /**
     * @notice checks inputs for calculating margin, reverts if bad inputs
     * @param _detail margin details
     */
    function _verifyInputs(CrossMarginDetail memory _detail) internal pure {
        if (_detail.callStrikes.length != _detail.callWeights.length) revert CMM_InvalidCallLengths();
        if (_detail.putStrikes.length != _detail.putWeights.length) revert CMM_InvalidPutLengths();

        uint256 i;
        for (i; i < _detail.putWeights.length;) {
            if (_detail.putWeights[i] == sZERO) revert CMM_InvalidPutWeight();

            unchecked {
                ++i;
            }
        }

        for (i = ZERO; i < _detail.callWeights.length;) {
            if (_detail.callWeights[i] == sZERO) revert CMM_InvalidCallWeight();

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice setting up values needed to calculate margin requirements
     * @param _detail margin details
     * @return pois array of point-of-interests (aka strikes)
     * @return payouts payouts for a given poi position
     */
    function _baseSetup(CrossMarginDetail memory _detail)
        internal
        pure
        returns (uint256[] memory pois, int256[] memory payouts)
    {
        bool hasPuts = _detail.putStrikes.length > ZERO;
        bool hasCalls = _detail.callStrikes.length > ZERO;

        pois = _detail.putStrikes.concat(_detail.callStrikes).sort();

        // payouts at each point-of-interest
        payouts = new int256[](pois.length);

        for (uint256 i; i < pois.length;) {
            if (hasPuts) payouts[i] = _detail.putStrikes.subEachBy(pois[i]).maximum(sZERO).dot(_detail.putWeights) / sUNIT;

            if (hasCalls) payouts[i] += _detail.callStrikes.subEachFrom(pois[i]).maximum(sZERO).dot(_detail.callWeights) / sUNIT;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice get numeraire and underlying needed to fully collateralize
     * @dev calculates left side and right side of the payout profile
     * @param _detail margin details
     * @param pois are the strikes we are evaluating
     * @param payouts are the payouts at a given strike
     * @return numeraireNeeded with {numeraire asset's} decimals
     * @return underlyingNeeded with {underlying asset's} decimals
     */
    function _calcCollateralNeeds(CrossMarginDetail memory _detail, uint256[] memory pois, int256[] memory payouts)
        internal
        pure
        returns (uint256 numeraireNeeded, uint256 underlyingNeeded)
    {
        bool hasPuts = _detail.putStrikes.length > ZERO;
        bool hasCalls = _detail.callStrikes.length > ZERO;

        // if put options exist, get amount of numeraire needed (left side of payout profile)
        if (hasPuts) numeraireNeeded = _getNumeraireNeeded(payouts, _detail.putStrikes, _detail.putWeights);

        // if call options exist, get amount of underlying needed (right side of payout profile)
        if (hasCalls) underlyingNeeded = _getUnderlyingNeeded(_detail.callWeights);

        // crediting the numeraire if underlying has a positive payout
        numeraireNeeded = _getUnderlyingAdjustedNumeraireNeeded(pois, payouts, numeraireNeeded, underlyingNeeded);
    }

    /**
     * @notice computes the slope to the left of the left most strike (put options)
     * @dev only called if there are put options, usually denominated in cash
     * @param payouts are the payouts at a given strike
     * @param putStrikes put option strikes
     * @param putWeights number of put options at a coorisponding strike
     * @return numeraireNeeded amount of numeraire asset needed
     */
    function _getNumeraireNeeded(int256[] memory payouts, uint256[] memory putStrikes, int256[] memory putWeights)
        internal
        pure
        returns (uint256 numeraireNeeded)
    {
        int256 minPayout = payouts.min();

        int256 _numeraireNeeded = putStrikes.dot(putWeights) / sUNIT;

        if (_numeraireNeeded > minPayout) _numeraireNeeded = minPayout;

        if (_numeraireNeeded < sZERO) numeraireNeeded = uint256(-_numeraireNeeded);
    }

    /**
     * @notice computes the slope to the right of the right most strike (call options), resulting in the delta hedge (underlying)
     * @dev only called if there are call options
     * @param callWeights number of call options at a coorisponding strike
     * @return underlyingNeeded amount of underlying needed
     */
    function _getUnderlyingNeeded(int256[] memory callWeights) internal pure returns (uint256 underlyingNeeded) {
        int256 totalCalls = callWeights.sum();

        if (totalCalls < sZERO) underlyingNeeded = uint256(-totalCalls);
    }

    /**
     * @notice crediting the numeraire if underlying has a positive payout
     * @dev checks if subAccount has positive underlying value, if it does then cash requirements can be lowered
     * @param pois option strikes
     * @param payouts payouts at coorisponding pois
     * @param numeraireNeeded current numeraire needed
     * @param underlyingNeeded underlying needed
     * @return numeraireNeeded adjusted numerarie needed
     */
    function _getUnderlyingAdjustedNumeraireNeeded(
        uint256[] memory pois,
        int256[] memory payouts,
        uint256 numeraireNeeded,
        uint256 underlyingNeeded
    ) internal pure returns (uint256) {
        (int256 minStrikePayout, uint256 index) = payouts.minWithIndex();

        minStrikePayout = -minStrikePayout;

        if (numeraireNeeded.toInt256() < minStrikePayout) {
            uint256 underlyingPayoutAtMinStrike = (pois[index] * underlyingNeeded) / UNIT;

            if (underlyingPayoutAtMinStrike.toInt256() > minStrikePayout) {
                numeraireNeeded = ZERO;
            } else {
                // check directly above means minStrikePayout > underlyingPayoutAtMinStrike
                numeraireNeeded = uint256(minStrikePayout) - underlyingPayoutAtMinStrike;
            }
        }

        return numeraireNeeded;
    }

    /**
     * @notice converts numerarie needed entirely in underlying
     * @dev only used if options collateralizied in underlying
     * @param pois option strikes
     * @param payouts payouts at coorisponding pois
     * @param underlyingNeeded current underlying needed
     * @return underlyingOnlyNeeded adjusted underlying needed
     */
    function _convertCallCollateralToUnderlying(uint256[] memory pois, int256[] memory payouts, uint256 underlyingNeeded)
        internal
        pure
        returns (uint256 underlyingOnlyNeeded)
    {
        int256 maxPayoutsOverPoi;
        int256[] memory payoutsOverPoi = new int256[](pois.length);

        for (uint256 i; i < pois.length;) {
            payoutsOverPoi[i] = (-payouts[i] * sUNIT) / int256(pois[i]);

            if (payoutsOverPoi[i] > maxPayoutsOverPoi) maxPayoutsOverPoi = payoutsOverPoi[i];

            unchecked {
                ++i;
            }
        }

        underlyingOnlyNeeded = underlyingNeeded;

        if (maxPayoutsOverPoi > sZERO) underlyingOnlyNeeded += uint256(maxPayoutsOverPoi);
    }

    /*///////////////////////////////////////////////////////////////
                         Setup CrossMarginDetail
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  converts Position struct arrays to in-memory detail struct arrays
     */
    function _getPositionDetails(IGrappa grappa, Position[] calldata shorts, Position[] calldata longs)
        internal
        view
        returns (CrossMarginDetail[] memory details)
    {
        details = new CrossMarginDetail[](ZERO);

        // used to reference which detail struct should be updated for a given position
        bytes32[] memory usceLookUp = new bytes32[](ZERO);

        Position[] memory positions = shorts.concat(longs);
        uint256 shortLength = shorts.length;

        for (uint256 i; i < positions.length;) {
            (, uint40 productId, uint64 expiry,,) = positions[i].tokenId.parseTokenId();

            ProductDetails memory product = _getProductDetails(grappa, productId);

            bytes32 pos = keccak256(abi.encode(product.underlyingId, product.strikeId, expiry));

            (bool found, uint256 index) = ArrayUtil.indexOf(usceLookUp, pos);

            CrossMarginDetail memory detail;

            if (found) {
                detail = details[index];
            } else {
                usceLookUp = ArrayUtil.append(usceLookUp, pos);

                detail.underlyingId = product.underlyingId;
                detail.underlyingDecimals = product.underlyingDecimals;
                detail.numeraireId = product.strikeId;
                detail.numeraireDecimals = product.strikeDecimals;
                detail.expiry = expiry;

                details = details.append(detail);
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
    function _processDetailWithToken(CrossMarginDetail memory detail, uint256 tokenId, int256 amount) internal pure {
        (TokenType tokenType,,, uint64 strike,) = tokenId.parseTokenId();

        bool found;
        uint256 index;

        // adjust or append to callStrikes array or callWeights array.
        if (tokenType == TokenType.CALL) {
            (found, index) = detail.callStrikes.indexOf(strike);

            if (found) {
                detail.callWeights[index] += amount;

                if (detail.callWeights[index] == sZERO) {
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

                if (detail.putWeights[index] == sZERO) {
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
        (,, uint8 underlyingId, uint8 strikeId,) = ProductIdUtil.parseProductId(productId);

        (,, address underlying, uint8 underlyingDecimals, address strike, uint8 strikeDecimals,,) =
            grappa.getDetailFromProductId(productId);

        info.underlying = underlying;
        info.underlyingId = underlyingId;
        info.underlyingDecimals = underlyingDecimals;
        info.strike = strike;
        info.strikeId = strikeId;
        info.strikeDecimals = strikeDecimals;
    }
}
