// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

library MoneynessLib {
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
        // assume long strike is higher than short strike.
        unchecked {
            return min(getCallCashValue(_spot, _longStrike), _shortStrike - _longStrike);
        }
    }

    /**
     * @notice  get the cash value of a debit put spread
     * @dev     retuns min(max(strike - spot, 0), longStrike - shortStrike)
     * @dev     expect long strike to be higher than short strike
     * @param _spot spot price
     * @param _longStrike strike price of the long call
     * @param _longStrike strike price of the short call
     */
    function getCashValueDebitPutSpread(
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
