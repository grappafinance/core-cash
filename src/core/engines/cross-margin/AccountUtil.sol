// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// cross margin types
import "./types.sol";

library AccountUtil {
    function append(CrossMarginDetail[] memory x, CrossMarginDetail memory v)
        internal
        pure
        returns (CrossMarginDetail[] memory y)
    {
        y = new CrossMarginDetail[](x.length + 1);
        uint256 i;
        for (i; i < x.length;) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    function append(Position[] memory x, Position memory v) internal pure returns (Position[] memory y) {
        y = new Position[](x.length + 1);
        uint256 i;
        for (i; i < x.length;) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    function concat(Position[] memory a, Position[] memory b) internal pure returns (Position[] memory y) {
        y = new Position[](a.length + b.length);
        uint256 v;
        uint256 i;
        for (i; i < a.length;) {
            y[v] = a[i];
            unchecked {
                ++i;
                ++v;
            }
        }
        for (i = 0; i < b.length;) {
            y[v] = b[i];
            unchecked {
                ++i;
                ++v;
            }
        }
    }

    function find(Position[] memory x, uint256 v) internal pure returns (bool f, Position memory p, uint256 i) {
        for (i; i < x.length;) {
            if (x[i].tokenId == v) {
                p = x[i];
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function indexOf(Position[] memory x, uint256 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length;) {
            if (x[i].tokenId == v) {
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function isEmpty(Position[] memory x) internal pure returns (bool e) {
        e = true;
        for (uint256 i; i < x.length;) {
            if (x[i].amount > 0) {
                e = false;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function removeAt(Position[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }
}
