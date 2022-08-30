// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "../config/types.sol";
import "../config/constants.sol";

library MoneynessLib {
    using FixedPointMathLib for uint256;

    /**
     * @notice   get the cash value of a call option strike
     * @dev      returns max(spot - strike, 0)
     * @param _spot  spot price in usd term with 6 decimals
     * @param _strike strike price in usd term with 6 decimals
     **/
    function getCallCashValue(uint256 _spot, uint256 _strike) internal pure returns (uint256) {
        unchecked {
            return _spot < _strike ? 0 : _spot - _strike;
        }
    }

    /**
     * @notice   get the cash value of a put option strike
     * @dev      returns max(strike - spot, 0)
     * @param _spot spot price in usd term with 6 decimals
     * @param _strike strike price in usd term with 6 decimals
     **/
    function getPutCashValue(uint256 _spot, uint256 _strike) internal pure returns (uint256) {
        unchecked {
            return _spot > _strike ? 0 : _strike - _spot;
        }
    }

    /**
     * @notice  get the cash value of a debit call spread
     * @dev     retuns min(max(spot - strike, 0), shortStrike - longStrike)
     * @dev     expect long strike to be lower than short strike
     * @param _spot spot price
     * @param _longStrike strike price of the long call
     * @param _longStrike strike price of the short call
     */
    function getCashValueDebitCallSpread(
        uint256 _spot,
        uint256 _longStrike,
        uint256 _shortStrike
    ) internal pure returns (uint256) {
        // assume long strike is lower than short strike.
        unchecked {
            if (_spot > _shortStrike) return _shortStrike - _longStrike;
            // expired itm, capped at (short - long)
            else if (_spot > _longStrike) return _spot - _longStrike;
            // expired itm
            else return 0;
        }
    }

    /**
     * @notice  get the cash value of a debit put spread
     * @dev     retuns min(max(strike - spot, 0), longStrike - shortStrike)
     * @dev     expect long strike to be higher than short strike
     * @param _spot spot price
     * @param _longStrike strike price of the long put
     * @param _longStrike strike price of the short put
     */
    function getCashValueDebitPutSpread(
        uint256 _spot,
        uint256 _longStrike,
        uint256 _shortStrike
    ) internal pure returns (uint256) {
        unchecked {
            if (_spot < _shortStrike) return _longStrike - _shortStrike;
            // expired itm, capped at (long - short)
            else if (_spot < _longStrike) return _longStrike - _spot;
            // expired itm
            else return 0;
        }
    }
}
