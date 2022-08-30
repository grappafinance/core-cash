// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

library NumberUtil {
    /**
     * @dev use it in uncheck so overflow will still be checked.
     */
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(x == 0 || (x * y) / x == y)
            if iszero(or(iszero(x), eq(div(z, x), y))) {
                revert(0, 0)
            }
        }
    }

    /**
     * @notice convert decimals of an amount
     *
     * @param  _amount      number to convert
     * @param _fromDecimals the decimals _amount has
     * @param _toDecimals   the target decimals
     *
     * @return _ number with _toDecimals decimals
     */
    function convertDecimals(
        uint256 _amount,
        uint8 _fromDecimals,
        uint8 _toDecimals
    ) internal pure returns (uint256) {
        if (_fromDecimals == _toDecimals) return _amount;

        if (_fromDecimals > _toDecimals) {
            uint8 diff;
            unchecked {
                diff = _fromDecimals - _toDecimals;
                // div cannot underflow because diff 10**diff != 0
                return _amount / (10**diff);
            }
        } else {
            uint8 diff;
            unchecked {
                diff = _toDecimals - _fromDecimals;
            }
            return _amount * (10**diff);
        }
    }
}
