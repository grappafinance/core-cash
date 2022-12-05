// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "../config/types.sol";
import "../config/constants.sol";

/**
 * @title MoneynessLib
 * @dev Library to calculate the moneyness of options
 */
library MoneynessLib {
    using FixedPointMathLib for uint256;

    /**
     * @notice   get the cash value of a call option strike
     * @dev      returns max(spot - strike, 0)
     * @param spot  spot price in usd term with 6 decimals
     * @param strike strike price in usd term with 6 decimals
     *
     */
    function getCallCashValue(uint256 spot, uint256 strike) internal pure returns (uint256) {
        unchecked {
            return spot < strike ? 0 : spot - strike;
        }
    }

    /**
     * @notice   get the cash value of a put option strike
     * @dev      returns max(strike - spot, 0)
     * @param spot spot price in usd term with 6 decimals
     * @param strike strike price in usd term with 6 decimals
     *
     */
    function getPutCashValue(uint256 spot, uint256 strike) internal pure returns (uint256) {
        unchecked {
            return spot > strike ? 0 : strike - spot;
        }
    }

    /**
     * @notice  get the cash value of a debit call spread
     * @dev     retuns min(max(spot - strike, 0), shortStrike - longStrike)
     * @dev     expect long strike to be lower than short strike
     * @param spot spot price
     * @param longStrike strike price of the long call
     * @param shortStrike strike price of the short call
     */
    function getCashValueDebitCallSpread(uint256 spot, uint256 longStrike, uint256 shortStrike) internal pure returns (uint256) {
        // assume long strike is lower than short strike.
        unchecked {
            if (spot > shortStrike) return shortStrike - longStrike;
            // expired itm, capped at (short - long)
            else if (spot > longStrike) return spot - longStrike;
            // expired itm
            else return 0;
        }
    }

    /**
     * @notice  get the cash value of a debit put spread
     * @dev     retuns min(max(strike - spot, 0), longStrike - shortStrike)
     * @dev     expect long strike to be higher than short strike
     * @param spot spot price
     * @param longStrike strike price of the long put
     * @param longStrike strike price of the short put
     */
    function getCashValueDebitPutSpread(uint256 spot, uint256 longStrike, uint256 shortStrike) internal pure returns (uint256) {
        unchecked {
            if (spot < shortStrike) return longStrike - shortStrike;
            // expired itm, capped at (long - short)
            else if (spot < longStrike) return longStrike - spot;
            // expired itm
            else return 0;
        }
    }
}
