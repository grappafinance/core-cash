// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../config/types.sol";

/**
 * Operations on Balance struct
 */
library BalanceUtil {
    /**
     * @dev create a new Balance array with 1 more element
     * @param x balance array
     * @param v new value to add
     * @return y new balance array
     */
    function append(Balance[] memory x, Balance memory v) internal pure returns (Balance[] memory y) {
        y = new Balance[](x.length + 1);
        uint256 i;
        for (i; i < x.length;) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    /**
     * @dev check if a balance object for collateral id already exists
     * @param x balance array
     * @param v collateral id to search
     * @return f true if found
     * @return b Balance object
     * @return i index of the found entry
     */
    function find(Balance[] memory x, uint8 v) internal pure returns (bool f, Balance memory b, uint256 i) {
        for (i; i < x.length;) {
            if (x[i].collateralId == v) {
                b = x[i];
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev return the index of an elemnt balance array
     * @param x balance array
     * @param v collateral id to search
     * @return f true if found
     * @return i index of the found entry
     */
    function indexOf(Balance[] memory x, uint8 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length;) {
            if (x[i].collateralId == v) {
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev remove index y from balance array
     * @param x balance array
     * @param y collateral id remove
     */
    function remove(Balance[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }

    /**
     * @dev add up all amount in an Balance array
     */
    function sum(Balance[] memory x) internal pure returns (uint80 s) {
        for (uint256 i; i < x.length;) {
            s += x[i].amount;
            unchecked {
                ++i;
            }
        }
    }
}
