// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
            if iszero(or(iszero(x), eq(div(z, x), y))) { revert(0, 0) }
        }
    }

    /**
     * @notice convert decimals of an amount
     *
     * @param  amount      number to convert
     * @param fromDecimals the decimals amount has
     * @param toDecimals   the target decimals
     *
     * @return newAmount number with toDecimals decimals
     */
    function convertDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return amount;

        if (fromDecimals > toDecimals) {
            uint8 diff;
            unchecked {
                diff = fromDecimals - toDecimals;
                // div cannot underflow because diff 10**diff != 0
                return amount / (10 ** diff);
            }
        } else {
            uint8 diff;
            unchecked {
                diff = toDecimals - fromDecimals;
            }
            return amount * (10 ** diff);
        }
    }
}
