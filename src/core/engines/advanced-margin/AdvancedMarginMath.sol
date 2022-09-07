// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
import "../../../libraries/NumberUtil.sol";

import "../../../config/constants.sol";
import "../../../config/types.sol";
import "../../../config/errors.sol";

/**
 * @title   AdvancedMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given advanced margin account
 *
 *                  sqrt(expiry - now) - sqrt(D_lower)
 * M = (r_lower + -------------------------------------  * (r_upper - r_lower))  * vol * v_multiplier
 *                    sqrt(D_upper) - sqrt(D_lower)
 *
 *                                s^2
 * min_call (s, k) = M * min (s, ----- * max(v, 1), k ) + max (0, s - k)
 *                                 k
 *
 *                                k^2
 * min_put (s, k)  = M * min (s, ----- * max(v, 1), k ) + max (0, k - s)
 *                                 s
 */
library AdvancedMarginMath {
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _account margin account
     * @param _assets product asset detail
     * @param _spotUnderlyingStrike underlying/strike spot price
     * @param _spotCollateralStrike collateral/strike spot price, can be 0 if collateral = strike
     * @param _param specific product parameters
     */
    function getMinCollateral(
        AdvancedMarginDetail memory _account,
        ProductDetails memory _assets,
        uint256 _spotUnderlyingStrike,
        uint256 _spotCollateralStrike,
        uint256 _vol,
        ProductMarginParams memory _param
    ) internal view returns (uint256 minCollatUnit) {
        // this is denominated in strike, with {UNIT_DECIMALS} decimals
        uint256 minCollatValueInStrike = getMinCollateralInStrike(_account, _spotUnderlyingStrike, _vol, _param);

        if (_assets.collateral == _assets.strike) return minCollatValueInStrike;

        // if collateral is not strike, calculate how much collateral needed by devidede by collat price.
        // will revert if _spotCollateralStrike is 0.
        minCollatUnit = minCollatValueInStrike.mulDivUp(UNIT, _spotCollateralStrike);
    }

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _account margin account
     * @param _spot underlying/strike spot price
     * @param _params specific product parameters
     * @return minCollatValueInStrike minimum collateral in strike (USD) value. with {BASE_UNIT} decimals
     */
    function getMinCollateralInStrike(
        AdvancedMarginDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory _params
    ) internal view returns (uint256 minCollatValueInStrike) {
        // don't need collateral
        if (_account.putAmount == 0 && _account.callAmount == 0) return 0;

        if (_params.rUpper == 0) revert AM_NoConfig();

        // we only have short put
        if (_account.callAmount == 0) {
            return getMinCollateralForPutSpread(_account, _spot, _vol, _params);
        }
        // we only have short call
        if (_account.putAmount == 0) {
            return getMinCollateralForCallSpread(_account, _spot, _vol, _params);
        }
        // we have both call and short
        else {
            return getMinCollateralForDoubleShort(_account, _spot, _vol, _params);
        }
    }

    function getMinCollateralForDoubleShort(
        AdvancedMarginDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        // there're both short call and put in the position
        uint256 minCollateralCall = getMinCollateralForCallSpread(_account, _spot, _vol, params);
        uint256 minCollateralPut = getMinCollateralForPutSpread(_account, _spot, _vol, params);

        if (_account.shortPutStrike < _account.shortCallStrike) {
            // if strikes don't cross (put strike < call strike),
            // you only need collateral of higher risk of either put or call
            return max(minCollateralCall, minCollateralPut);
        } else {
            // if strike crosses, it became more risky between shortStrike -> putStrike
            // but the max loss could be capped
            return minCollateralCall + minCollateralPut;

            // todo: if the amount is the same, capped at the max loss
        }
    }

    function getMinCollateralForCallSpread(
        AdvancedMarginDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        // if max loss of short can always be covered by long
        if (_account.longCallStrike != 0 && _account.longCallStrike < _account.shortCallStrike) return 0;

        // it's a simple short call position
        uint256 minCollateralShortCall = getMinCollateralForShortCall(
            _account.callAmount,
            _account.shortCallStrike,
            _account.expiry,
            _spot,
            _vol,
            params
        );
        if (_account.longCallStrike == 0) return minCollateralShortCall;

        // we calculate the max loss of spread, dominated in strke asset (usually USD)
        unchecked {
            uint256 maxLoss = (_account.longCallStrike - _account.shortCallStrike).mul(_account.callAmount) / UNIT;
            return min(maxLoss, minCollateralShortCall);
        }
    }

    function getMinCollateralForPutSpread(
        AdvancedMarginDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        // if max loss of short can always be covered by long
        if (_account.longPutStrike > _account.shortPutStrike) return 0;

        // long is not sufficient to cap loss for short, result is the same as
        uint256 minCollateralShortPut = getMinCollateralForShortPut(
            _account.putAmount,
            _account.shortPutStrike,
            _account.expiry,
            _spot,
            _vol,
            params
        );

        if (_account.longPutStrike == 0) return minCollateralShortPut;

        // we calculate the max loss of the put spread
        unchecked {
            uint256 maxLoss = (_account.shortPutStrike - _account.longPutStrike).mul(_account.putAmount) / UNIT;
            return min(minCollateralShortPut, maxLoss);
        }
    }

    /**
     * @notice get the minimum collateral for a naked short option
     * @dev calculated with the following formula:
     *
     *  M = timeDecay  * vol + v_multiplier
     *
     *                                 s^2
     *  min_call (s, k) = M * min (s, ----- * max(v, 1), k ) + cashValue
     *                                  k
     *
     * @return collateral denominated in strike asset, with 6 decimals
     **/
    function getMinCollateralForShortCall(
        uint256 _shortAmount,
        uint256 _strike,
        uint256 _expiry,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        // todo: make sure strike cannot be 0!
        uint256 timeValueDecay = getTimeDecay(_expiry, params);

        uint256 cashValue = MoneynessLib.getCallCashValue(_spot, _strike);

        uint256 tempMin = min(_strike, _spot);

        // uint256 otmReq = max(_vol, UNIT).mulDivUp(_spot, UNIT).mulDivUp(_spot, _strike);
        uint256 otmReq = (max(_vol, UNIT) * _spot).mulDivUp(_spot, _strike);
        unchecked {
            otmReq = otmReq / UNIT;
        }

        tempMin = min(tempMin, otmReq);

        uint256 requiredCollateral = tempMin;
        unchecked {
            // use mul() and / instead of mulDiv to skip check
            requiredCollateral = tempMin.mul(timeValueDecay) / BPS + cashValue;
            return requiredCollateral.mul(_shortAmount) / UNIT;
        }
    }

    /**
     * @notice get the minimum collateral for a naked put option
     * @dev calculated with the following formula:
     *
     *  M = timeDecay  * vol + v_multiplier
     *
     *                                 k^2
     *  min_call (s, k) = M * min (s, ----- * max(v, 1), k ) + cashValue
     *                                  s
     *
     * @return collateral denominated in strike asset, with 6 decimals
     **/
    function getMinCollateralForShortPut(
        uint256 _shortAmount,
        uint256 _strike,
        uint256 _expiry,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        unchecked {
            if (_spot == 0) return _strike.mul(_shortAmount) / UNIT;
        }

        // get time decay in BPS
        uint256 timeValueDecay = getTimeDecay(_expiry, params);

        uint256 cashValue = MoneynessLib.getPutCashValue(_spot, _strike);

        uint256 tempMin = min(_strike, _spot);

        // uint256 otmReq = max(_vol, UNIT).mulDivUp(_strike, UNIT).mulDivUp(_strike, _spot);
        uint256 otmReq = (max(_vol, UNIT) * _strike).mulDivUp(_strike, _spot);
        unchecked {
            otmReq = otmReq / UNIT;
        }
        tempMin = min(tempMin, otmReq);

        unchecked {
            uint256 requiredCollateral = tempMin.mul(timeValueDecay) / BPS + cashValue;
            return requiredCollateral.mul(_shortAmount) / UNIT;
        }
    }

    /**
     * @notice  get the time decay value
     * @dev     timeDecay is calculated with the following formula, should be a number between [0, 1]
     *
     *                      sqrt(t - now) - sqrt(D_lower)
     * d(t) = (r_lower + ------------------------------------  * (r_upper - r_lower))
     *                      sqrt(D_upper) - sqrt(D_lower)
     *
     * @param _expiry expiry timestamp
     *
     * @return timeDecay in BPS
     */
    function getTimeDecay(uint256 _expiry, ProductMarginParams memory params) internal view returns (uint256) {
        if (_expiry <= block.timestamp) return 0;

        unchecked {
            uint256 timeToExpiry = _expiry - block.timestamp;

            if (timeToExpiry > params.dUpper) return uint256(params.rUpper);
            if (timeToExpiry < params.dLower) return uint256(params.rLower);

            return
                uint256(params.rLower) +
                ((timeToExpiry.sqrt() - params.sqrtDLower) * (params.rUpper - params.rLower)) /
                (params.sqrtDUpper - params.sqrtDLower);
        }
    }

    /// @dev return the max of a and b
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /// @dev return the min of a and b
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
