pragma solidity ^0.8.0;

import "./ArrayUtil.sol";
import "../config/types.sol";

import "../test/utils/Console.sol";

library AccountUtil {
    function append(Balance[] memory x, Balance memory v) internal pure returns (Balance[] memory y) {
        y = new Balance[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                i++;
            }
        }
        y[i] = v;
    }

    function append(FullMarginDetailV2[] memory x, FullMarginDetailV2 memory v)
        internal
        pure
        returns (FullMarginDetailV2[] memory y)
    {
        y = new FullMarginDetailV2[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                i++;
            }
        }
        y[i] = v;
    }

    function append(SBalance[] memory x, SBalance memory v) internal pure returns (SBalance[] memory y) {
        y = new SBalance[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                i++;
            }
        }
        y[i] = v;
    }

    function concat(Position[] memory a, Position[] memory b) internal pure returns (Position[] memory y) {
        y = new Position[](a.length + b.length);
        uint256 v;
        uint256 i;
        for (i; i < a.length; ) {
            y[v] = a[i];
            unchecked {
                i++;
                v++;
            }
        }
        for (i = 0; i < b.length; ) {
            y[v] = b[i];
            unchecked {
                i++;
                v++;
            }
        }
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
                i++;
            }
        }
    }

    function find(Position[] memory x, uint8 v)
        internal
        pure
        returns (
            bool f,
            Position memory p,
            uint256 i
        )
    {
        for (i; i < x.length; ) {
            if (x[i].tokenId == v) {
                p = x[i];
                f = true;
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    function find(SBalance[] memory x, uint8 v)
        internal
        pure
        returns (
            bool f,
            SBalance memory b,
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
                i++;
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
                i++;
            }
        }
    }

    function indexOf(Position[] memory x, uint256 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length; ) {
            if (x[i].tokenId == v) {
                f = true;
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    function indexOf(SBalance[] memory x, uint8 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length; ) {
            if (x[i].collateralId == v) {
                f = true;
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    function remove(Balance[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }

    function remove(Position[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }

    function sum(Balance[] memory x) internal pure returns (uint80 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i].amount;
            unchecked {
                i++;
            }
        }
    }

    function sum(Position[] memory x) internal pure returns (uint64 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i].amount;
            unchecked {
                i++;
            }
        }
    }

    function toInt80(Balance[] memory x) internal pure returns (SBalance[] memory y) {
        y = new SBalance[](x.length);
        for (uint256 i; i < x.length; ) {
            y[i] = SBalance(x[i].collateralId, int80(x[i].amount));
            unchecked {
                i++;
            }
        }
    }
}
