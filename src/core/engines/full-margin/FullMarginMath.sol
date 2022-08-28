// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";

import "../../../config/constants.sol";
import "../../../config/types.sol";
import "../../../config/errors.sol";

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
                unchecked {
                    unitAmount = (_account.longStrike - _account.shortStrike).mulDivUp(
                        _account.shortAmount,
                        _account.longStrike
                    );
                }
            }
        } else if (_account.tokenType == TokenType.PUT) {
            unitAmount = (_account.shortStrike).mulDivUp(_account.shortAmount, UNIT);
        } else if (_account.tokenType == TokenType.PUT_SPREAD) {
            // if long strike >= short strike, all loss is covered, amount = 0
            // only consider when long strike < short strike
            if (_account.longStrike < _account.shortStrike) {
                unchecked {
                    unitAmount = (_account.shortStrike - _account.longStrike).mulDivUp(_account.shortAmount, UNIT);
                }
            }
        } else {
            revert("No Type");
        }

        return NumberUtil.convertDecimals(unitAmount, UNIT_DECIMALS, _account.collateralDecimals);
    }
}
