// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenIdUtil} from "./TokenIdUtil.sol";
import "./ArrayUtil.sol";
import "../config/types.sol";

import "../test/utils/Console.sol";

library AccountUtil {
    using TokenIdUtil for uint192;
    using TokenIdUtil for uint256;

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
                ++i;
            }
        }
        y[i] = v;
    }

    function append(Position[] memory x, Position memory v) internal pure returns (Position[] memory y) {
        y = new Position[](x.length + 1);
        uint256 i;
        for (i; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                ++i;
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
                ++i;
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
                ++i;
                ++v;
            }
        }
        for (i = 0; i < b.length; ) {
            y[v] = b[i];
            unchecked {
                ++i;
                ++v;
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
                ++i;
            }
        }
    }

    function find(Position[] memory x, uint256 v)
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
                ++i;
            }
        }
    }

    function find(PositionOptim[] memory x, uint192 v)
        internal
        pure
        returns (
            bool f,
            PositionOptim memory p,
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
                ++i;
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

    function indexOf(Position[] memory x, uint256 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length; ) {
            if (x[i].tokenId == v) {
                f = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function indexOf(PositionOptim[] memory x, uint192 v) internal pure returns (bool f, uint256 i) {
        for (i; i < x.length; ) {
            if (x[i].tokenId == v) {
                f = true;
                break;
            }
            unchecked {
                ++i;
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
                ++i;
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
                ++i;
            }
        }
    }

    function sum(PositionOptim[] memory x) internal pure returns (uint64 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i].amount;
            unchecked {
                ++i;
            }
        }
    }

    function toSBalances(Balance[] memory x) internal pure returns (SBalance[] memory y) {
        y = new SBalance[](x.length);
        for (uint256 i; i < x.length; ) {
            y[i] = SBalance(x[i].collateralId, int80(x[i].amount));
            unchecked {
                ++i;
            }
        }
    }

    function toBalances(SBalance[] memory x) internal pure returns (Balance[] memory y) {
        y = new Balance[](x.length);
        for (uint256 i; i < x.length; ) {
            int80 a = x[i].amount;
            a = a < 0 ? -a : a;
            y[i] = Balance(x[i].collateralId, uint80(a));
            unchecked {
                ++i;
            }
        }
    }

    function getPositions(PositionOptim[] memory x) internal pure returns (Position[] memory y) {
        y = new Position[](x.length);
        for (uint256 i; i < x.length; ) {
            y[i] = Position(x[i].tokenId.expand(), x[i].amount);
            unchecked {
                ++i;
            }
        }
    }

    function getPositionOptims(Position[] memory x) internal pure returns (PositionOptim[] memory y) {
        y = new PositionOptim[](x.length);
        for (uint256 i; i < x.length; ) {
            y[i] = getPositionOptim(x[i]);
            unchecked {
                ++i;
            }
        }
    }

    function pushPosition(PositionOptim[] storage x, Position memory y) internal {
        x.push(getPositionOptim(y));
    }

    function removePositionAt(PositionOptim[] storage x, uint256 y) internal {
        if (y >= x.length) return;
        x[y] = x[x.length - 1];
        x.pop();
    }

    function getPositionOptim(Position memory x) internal pure returns (PositionOptim memory) {
        return PositionOptim(x.tokenId.shorten(), x.amount);
    }
}
