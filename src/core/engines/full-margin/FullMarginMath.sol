// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";

import "../../../config/constants.sol";

// Full margin types
import "./types.sol";
import "./errors.sol";

/**
 * @title   FullMarginMath
 * @notice  this library is in charge of calculating the min collateral for a given simple margin account
 */
library FullMarginMath {
    using FixedPointMathLib for uint256;

    /**
     * @notice get minimum collateral denominated in strike asset
     * @param _account margin account
     * @return minCollatValueInStrike minimum collateral in strike (USD) value. with {BASE_UNIT} decimals
     */
    function getMinCollateral(FullMarginDetail memory _account) internal pure returns (uint256 minCollatValueInStrike) {
        // don't need collateral
        if (_account.shortAmount == 0) return 0;

        // amount with UNIT decimals
        uint256 unitAmount;

        if (_account.tokenType == TokenType.CALL) {
            unitAmount = _account.shortAmount;
        } else if (_account.tokenType == TokenType.CALL_SPREAD) {
            // if long strike <= short strike, all loss is covered, amount = 0
            // only consider when long strike > short strike
            if (_account.longStrike > _account.shortStrike) {
                // only call spread has option to be collateralized by strike or underlying
                if (_account.collateralizedWithStrike) {
                    // ex: 2000-4000 call spread with usdc collateral
                    // return (longStrike - shortStrike) * amount / unit

                    unchecked {
                        unitAmount = (_account.longStrike - _account.shortStrike);
                    }
                    unitAmount = unitAmount * _account.shortAmount;
                    unchecked {
                        unitAmount = unitAmount / UNIT;
                    }
                } else {
                    // ex: 2000-4000 call spread with eth collateral
                    unchecked {
                        unitAmount = (_account.longStrike - _account.shortStrike).mulDivUp(_account.shortAmount, _account.longStrike);
                    }
                }
            }
        } else if (_account.tokenType == TokenType.PUT) {
            // unitAmount = shortStrike * amount / UNIT
            unitAmount = _account.shortStrike * _account.shortAmount;
            unchecked {
                unitAmount = unitAmount / UNIT;
            }
        } else if (_account.tokenType == TokenType.PUT_SPREAD) {
            // if long strike >= short strike, all loss is covered, amount = 0
            // only consider when long strike < short strike
            if (_account.longStrike < _account.shortStrike) {
                // unitAmount = (shortStrike - longStrike) * amount / UNIT

                unchecked {
                    unitAmount = (_account.shortStrike - _account.longStrike);
                }
                unitAmount = unitAmount * _account.shortAmount;
                unchecked {
                    unitAmount = unitAmount / UNIT;
                }
            }
        } else {
            revert("No Type");
        }

        return NumberUtil.convertDecimals(unitAmount, UNIT_DECIMALS, _account.collateralDecimals);
    }
}
