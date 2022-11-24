// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../config/types.sol";

/**
 * Operations on Balance struct
 */
library BalanceUtil {
    function append(Balance[] memory x, Balance memory v) internal pure returns (Balance[] memory y) {
        y = new Balance[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    function find(Balance[] memory x, uint8 v)
        internal
        pure
        returns (
            bool f,
            Balance memory b,
            uint256 i
        )
    {
        for (i; i < x.length; ) {
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

    function indexOf(Balance[] memory x, uint8 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length; ) {
            if (x[i].collateralId == v) {
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function remove(Balance[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }

    function sum(Balance[] memory x) internal pure returns (uint80 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i].amount;
            unchecked {
                ++i;
            }
        }
    }
}
