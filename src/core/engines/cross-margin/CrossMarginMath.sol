// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {UintArrayLib} from "array-lib/UintArrayLib.sol";
import {IntArrayLib} from "array-lib/IntArrayLib.sol";

import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IOracle} from "../../../interfaces/IOracle.sol";

// shard libraries
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {BalanceUtil} from "../../../libraries/BalanceUtil.sol";
import {BytesArrayUtil} from "../../../libraries/BytesArrayUtil.sol";

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
    using UintArrayLib for uint256[];
    using IntArrayLib for int256[];
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
        if (details.length == 0) return amounts;

        bool found;
        uint256 index;

        for (uint256 i; i < details.length;) {
            CrossMarginDetail memory detail = details[i];

            // checks that the combination has positions, otherwiser skips
            if (detail.callWeights.length != 0 || detail.putWeights.length != 0) {
                // gets the amount of numeraire and underlying needed
                (uint256 numeraireNeeded, uint256 underlyingNeeded) = getMinCollateral(detail);

                if (numeraireNeeded != 0) {
                    (found, index) = amounts.indexOf(detail.numeraireId);

                    if (found) amounts[index].amount += numeraireNeeded.toUint80();
                    else amounts = amounts.append(Balance(detail.numeraireId, numeraireNeeded.toUint80()));
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

        (uint256[] memory scenarios, int256[] memory payouts) = _getScenariosAndPayouts(_detail);

        (numeraireNeeded, underlyingNeeded) = _getCollateralNeeds(_detail, scenarios, payouts);

        // if options collateralizied in underlying, forcing numeraire to be converted to underlying
        // only applied to calls since puts cannot be collateralized in underlying
        if (numeraireNeeded > 0 && _detail.putStrikes.length == 0) {
            numeraireNeeded = 0;

            underlyingNeeded = _convertCallNumeraireToUnderlying(scenarios, payouts, underlyingNeeded);
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
            if (_detail.putWeights[i] == 0) revert CMM_InvalidPutWeight();

            unchecked {
                ++i;
            }
        }

        for (i; i < _detail.callWeights.length;) {
            if (_detail.callWeights[i] == 0) revert CMM_InvalidCallWeight();

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice setting up values needed to calculate margin requirements
     * @param _detail margin details
     * @return scenarios array of all the strikes
     * @return payouts payouts for a given scenario
     */
    function _getScenariosAndPayouts(CrossMarginDetail memory _detail)
        internal
        pure
        returns (uint256[] memory scenarios, int256[] memory payouts)
    {
        bool hasPuts = _detail.putStrikes.length > 0;
        bool hasCalls = _detail.callStrikes.length > 0;

        scenarios = _detail.putStrikes.concat(_detail.callStrikes).sort();

        // payouts at each scenario (strike)
        payouts = new int256[](scenarios.length);

        uint256 lastScenario;

        for (uint256 i; i < scenarios.length;) {
            // deduping scenarios, leaving payout as 0
            if (scenarios[i] != lastScenario) {
                if (hasPuts) {
                    payouts[i] = _detail.putStrikes.subEachBy(scenarios[i]).maximum(0).dot(_detail.putWeights) / sUNIT;
                }

                if (hasCalls) {
                    payouts[i] += _detail.callStrikes.subEachFrom(scenarios[i]).maximum(0).dot(_detail.callWeights) / sUNIT;
                }

                lastScenario = scenarios[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice get numeraire and underlying needed to fully collateralize
     * @dev calculates left side and right side of the payout profile
     * @param _detail margin details
     * @param scenarios of all the options
     * @param payouts are the payouts at a given scenario
     * @return numeraireNeeded with {numeraire asset's} decimals
     * @return underlyingNeeded with {underlying asset's} decimals
     */
    function _getCollateralNeeds(CrossMarginDetail memory _detail, uint256[] memory scenarios, int256[] memory payouts)
        internal
        pure
        returns (uint256 numeraireNeeded, uint256 underlyingNeeded)
    {
        bool hasPuts = _detail.putStrikes.length > 0;
        bool hasCalls = _detail.callStrikes.length > 0;

        (int256 minPayout, uint256 minPayoutIndex) = payouts.minWithIndex();

        // if put options exist, get amount of numeraire needed (left side of payout profile)
        if (hasPuts) numeraireNeeded = _getNumeraireNeeded(minPayout, _detail.putStrikes, _detail.putWeights);

        // if call options exist, get amount of underlying needed (right side of payout profile)
        if (hasCalls) underlyingNeeded = _getUnderlyingNeeded(_detail.callWeights);

        // crediting the numeraire if underlying has a positive payout
        numeraireNeeded =
            _getUnderlyingAdjustedNumeraireNeeded(scenarios, minPayout, minPayoutIndex, numeraireNeeded, underlyingNeeded);
    }

    /**
     * @notice calculates the amount of numeraire is needed for put options
     * @dev only called if there are put options, usually denominated in cash
     * @param minPayout minimum payout across scenarios
     * @param putStrikes put option strikes
     * @param putWeights number of put options at a coorisponding strike
     * @return numeraireNeeded amount of numeraire asset needed
     */
    function _getNumeraireNeeded(int256 minPayout, uint256[] memory putStrikes, int256[] memory putWeights)
        internal
        pure
        returns (uint256 numeraireNeeded)
    {
        int256 _numeraireNeeded = putStrikes.dot(putWeights) / sUNIT;

        if (_numeraireNeeded > minPayout) _numeraireNeeded = minPayout;

        if (_numeraireNeeded < 0) numeraireNeeded = uint256(-_numeraireNeeded);
    }

    /**
     * @notice calculates the amount of underlying is needed for call options
     * @dev only called if there are call options
     * @param callWeights number of call options at a coorisponding strike
     * @return underlyingNeeded amount of underlying needed
     */
    function _getUnderlyingNeeded(int256[] memory callWeights) internal pure returns (uint256 underlyingNeeded) {
        int256 totalCalls = callWeights.sum();

        if (totalCalls < 0) underlyingNeeded = uint256(-totalCalls);
    }

    /**
     * @notice crediting the numeraire if underlying has a positive payout
     * @dev checks if subAccount has positive underlying value, if it does then cash requirements can be lowered
     * @param scenarios of all the options
     * @param minPayout minimum payout across scenarios
     * @param minPayoutIndex minimum payout across scenarios index
     * @param numeraireNeeded current numeraire needed
     * @param underlyingNeeded underlying needed
     * @return numeraireNeeded adjusted numerarie needed
     */
    function _getUnderlyingAdjustedNumeraireNeeded(
        uint256[] memory scenarios,
        int256 minPayout,
        uint256 minPayoutIndex,
        uint256 numeraireNeeded,
        uint256 underlyingNeeded
    ) internal pure returns (uint256) {
        // negating to focus on negative payouts which require positive collateral
        minPayout = -minPayout;

        if (numeraireNeeded.toInt256() < minPayout) {
            uint256 underlyingPayoutAtMinStrike = (scenarios[minPayoutIndex] * underlyingNeeded) / UNIT;

            if (underlyingPayoutAtMinStrike.toInt256() > minPayout) {
                numeraireNeeded = 0;
            } else {
                // check directly above means minPayout > underlyingPayoutAtMinStrike
                numeraireNeeded = uint256(minPayout) - underlyingPayoutAtMinStrike;
            }
        }

        return numeraireNeeded;
    }

    /**
     * @notice converts numerarie needed entirely in underlying
     * @dev only used if options collateralizied in underlying
     * @param scenarios of all the options
     * @param payouts payouts at coorisponding scenarios
     * @param underlyingNeeded current underlying needed
     * @return underlyingOnlyNeeded adjusted underlying needed
     */
    function _convertCallNumeraireToUnderlying(uint256[] memory scenarios, int256[] memory payouts, uint256 underlyingNeeded)
        internal
        pure
        returns (uint256 underlyingOnlyNeeded)
    {
        int256 maxPayoutsOverScenarios;
        int256[] memory payoutsOverScenarios = new int256[](scenarios.length);

        for (uint256 i; i < scenarios.length;) {
            payoutsOverScenarios[i] = (-payouts[i] * sUNIT) / int256(scenarios[i]);

            if (payoutsOverScenarios[i] > maxPayoutsOverScenarios) maxPayoutsOverScenarios = payoutsOverScenarios[i];

            unchecked {
                ++i;
            }
        }

        underlyingOnlyNeeded = underlyingNeeded;

        if (maxPayoutsOverScenarios > 0) underlyingOnlyNeeded += uint256(maxPayoutsOverScenarios);
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
        details = new CrossMarginDetail[](0);

        // used to reference which detail struct should be updated for a given position
        bytes32[] memory usceLookUp = new bytes32[](0);

        Position[] memory positions = shorts.concat(longs);
        uint256 shortLength = shorts.length;

        for (uint256 i; i < positions.length;) {
            (, uint40 productId, uint64 expiry,,) = positions[i].tokenId.parseTokenId();

            ProductDetails memory product = _getProductDetails(grappa, productId);

            bytes32 pos = keccak256(abi.encode(product.underlyingId, product.strikeId, expiry));

            (bool found, uint256 index) = BytesArrayUtil.indexOf(usceLookUp, pos);

            CrossMarginDetail memory detail;

            if (found) {
                detail = details[index];
            } else {
                usceLookUp = BytesArrayUtil.append(usceLookUp, pos);

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
