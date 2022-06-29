// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "src/config/constants.sol";
import "src/config/types.sol";
import "src/config/errors.sol";

import "forge-std/console2.sol";

library SimpleMarginMath {
    using FixedPointMathLib for uint256;

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _account margin account
     * @param _assets product asset detail
     * @param _spotUnderlyingStrike underlying/strike spot price
     * @param _spotCollateralStrike collateral/strike spot price, can be 0 if collateral = strike
     * @param _param specific product parameters
     */
    function getMinCollateral(
        MarginAccountDetail memory _account,
        ProductAssets memory _assets,
        uint256 _spotUnderlyingStrike,
        uint256 _spotCollateralStrike,
        ProductMarginParams memory _param
    ) internal view returns (uint256 minCollatUnit) {
        // this is denominated in strike, with {UNIT_DECIMALS} decimals
        uint256 minCollatValueInStrike = getMinCollateralInStrike(_account, _spotUnderlyingStrike, UNIT, _param);

        if (_assets.collateral == _assets.strike) return minCollatValueInStrike;

        // if collateral is not strike, calculate how much collateral needed by devidede by collat price.
        // will revert if _spotCollateralStrike is 0.
        minCollatUnit = minCollatValueInStrike.mulDivUp(UNIT_DECIMALS, _spotCollateralStrike);
    }

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _account margin account
     * @param _spot underlying/strike spot price
     * @param _params specific product parameters
     * @return minCollatValueInStrike minimum collateral in strike (USD) value. with {BASE_UNIT} decimals
     */
    function getMinCollateralInStrike(
        MarginAccountDetail memory _account,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory _params
    ) internal view returns (uint256 minCollatValueInStrike) {
        // don't need collateral
        if (_account.putAmount == 0 && _account.callAmount == 0) return 0;

        if (_params.discountRatioUpperBound == 0) revert InvalidConfig();

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
        MarginAccountDetail memory _account,
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
        MarginAccountDetail memory _account,
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
            uint256 maxLoss = (_account.longCallStrike - _account.shortCallStrike).mulDivUp(_account.callAmount, UNIT);
            return min(maxLoss, minCollateralShortCall);
        }
    }

    function getMinCollateralForPutSpread(
        MarginAccountDetail memory _account,
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
            uint256 maxLoss = (_account.shortPutStrike - _account.longPutStrike).mulDivUp(_account.putAmount, UNIT);
            return min(minCollateralShortPut, maxLoss);
        }
    }

    ///@notice get the minimum collateral for a naked short option
    ///@dev margin = cashValue + decay(t) * v * min(spot, K, max(v,1) * spot^2 / strike)
    ///     decay(t) = a multiplier from [0, 1]
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

        uint256 cashValue = getCallCashValue(_spot, _strike);

        uint256 tempMin = min(_strike, _spot);

        uint256 otmReq = max(_vol, 1).mulDivUp(_spot, UNIT).mulDivUp(_spot, _strike);
        tempMin = min(tempMin, otmReq);

        uint256 requireCollateral = tempMin.mulDivUp(timeValueDecay, BPS) + cashValue;

        return requireCollateral.mulDivUp(_shortAmount, UNIT);
    }

    ///@notice get the minimum collateral for a put option
    ///@dev margin = cashValue + decay(t) * v * min(spot, K, max(v,1) * strike^2 /spot)
    ///     decay(t) = a multiplier from [0, 1]
    function getMinCollateralForShortPut(
        uint256 _shortAmount,
        uint256 _strike,
        uint256 _expiry,
        uint256 _spot,
        uint256 _vol,
        ProductMarginParams memory params
    ) internal view returns (uint256) {
        if (_spot == 0) return _strike.mulDivUp(_shortAmount, UNIT);

        // get time decay in BPS
        uint256 timeValueDecay = getTimeDecay(_expiry, params);

        uint256 cashValue = getPutCashValue(_spot, _strike);

        uint256 tempMin = min(_strike, _spot);

        uint256 otmReq = max(_vol, 1).mulDivUp(_strike, UNIT).mulDivUp(_strike, _spot);
        tempMin = min(tempMin, otmReq);

        uint256 requireCollateral = tempMin.mulDivUp(timeValueDecay, BPS) + cashValue;

        uint256 ans = requireCollateral.mulDivUp(_shortAmount, UNIT);
        return ans;
    }

    /**
     * get the time decay value apply to minimum collateral
     * @param _expiry expiry timestamp
     */
    function getTimeDecay(uint256 _expiry, ProductMarginParams memory params) internal view returns (uint256) {
        if (_expiry <= block.timestamp) return 0;

        uint256 timeToExpiry = _expiry - block.timestamp;
        if (timeToExpiry > params.discountPeriodUpperBound) return uint256(params.discountRatioUpperBound); // 80%
        if (timeToExpiry < params.discountPeriodLowerBound) return uint256(params.discountRatioLowerBound); // 10% of time value

        return
            uint256(params.discountRatioLowerBound) +
            ((timeToExpiry.sqrt() - params.sqrtMinDiscountPeriod) *
                (params.discountRatioUpperBound - params.discountRatioLowerBound)) /
            (params.sqrtMaxDiscountPeriod - params.sqrtMinDiscountPeriod);
    }

    /// @notice get the cash value of a call option strike
    /// @dev returns max(spot - strike, 0)
    /// @param _spot spot price in usd term with 8 decimals
    /// @param _strike strike price in usd term with 8 decimals
    function getCallCashValue(uint256 _spot, uint256 _strike) internal pure returns (uint256) {
        unchecked {
            return _spot < _strike ? 0 : _spot - _strike;
        }
    }

    /// @notice get the cash value of a put option strike
    /// @dev returns max(strike - spot, 0)
    /// @param _spot spot price in usd term with 8 decimals
    /// @param _strike strike price in usd term with 8 decimals
    function getPutCashValue(uint256 _spot, uint256 _strike) internal pure returns (uint256) {
        unchecked {
            return _spot > _strike ? 0 : _strike - _spot;
        }
    }

    function getCashValueCallDebitSpread(
        uint256 _spot,
        uint256 _longStrike,
        uint256 _shortStrike
    ) internal pure returns (uint256) {
        unchecked {
            return min(getCallCashValue(_spot, _longStrike), _shortStrike - _longStrike);
        }
    }

    function getCashValuePutDebitSpread(
        uint256 _spot,
        uint256 _longStrike,
        uint256 _shortStrike
    ) internal pure returns (uint256) {
        unchecked {
            return min(getPutCashValue(_spot, _longStrike), _longStrike - _shortStrike);
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
