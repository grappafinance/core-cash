// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

library ArrayUtil {
    using SafeCast for uint256;
    using SafeCast for int256;

    error IndexOutOfBounds();

    /**
     * @dev Returns minimal element in array
     * @return m
     */
    function min(int256[] memory x) internal pure returns (int256 m) {
        m = x[0];
        for (uint256 i; i < x.length; ) {
            if (x[i] < m) {
                m = x[i];
            }
            unchecked {
                ++i;
            }
        }
    }

    function min(uint256[] memory x) internal pure returns (uint256 m) {
        m = x[0];
        for (uint256 i; i < x.length; ) {
            if (x[i] < m) {
                m = x[i];
            }
            unchecked {
                ++i;
            }
        }
    }

    // /**
    //  * @dev Returns minimal element's index
    //  * @return m
    //  */
    // function imin(uint256[] memory x) internal pure returns (uint256 m) {
    //     m = 0;
    //     for (uint256 i; i < x.length; i++) {
    //         if (x[i] < x[m]) {
    //             m = i;
    //         }
    //     }
    //     return m;
    // }

    /**
     * @dev Returns maximal element in array
     * @return m
     */
    function max(int256[] memory x) internal pure returns (int256 m) {
        m = x[0];
        for (uint256 i; i < x.length; i++) {
            if (x[i] > m) {
                m = x[i];
            }
        }
    }

    function max(uint256[] memory x) internal pure returns (uint256 m) {
        m = x[0];
        for (uint256 i; i < x.length; i++) {
            if (x[i] > m) {
                m = x[i];
            }
        }
    }

    /**
     * @dev Returns maximal elements comparedTo value
     * @return y array
     */
    function maximum(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length; i++) {
            if (x[i] > z) y[i] = x[i];
            else y[i] = z;
        }
    }

    // /**
    //  * @dev Returns maximal element's index
    //  * @return m maximal
    //  */
    // function imax(uint256[] memory x) internal pure returns (uint256 m) {
    //     for (uint256 i; i < x.length; i++) {
    //         if (x[i] > x[m]) {
    //             m = i;
    //         }
    //     }
    // }

    /**
     * @dev Removes element at index in a new array, does not change x memory in place
     * @return y new array
     */
    function remove(uint256[] memory x, uint256 z) internal pure returns (uint256[] memory y) {
        if (z >= x.length) return x;
        y = new uint256[](x.length - 1);
        for (uint256 i = 0; i < x.length; i++) {
            if (i < z) y[i] = x[i];
            else if (i > z) y[i] = x[i + 1];
        }
    }

    /**
     * @dev Returns index of element
     * @return found
     * @return index
     */
    function indexOf(int256[] memory x, int256 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length; ) {
            if (x[i] == v) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }

    function indexOf(bytes32[] memory x, bytes32 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length; ) {
            if (x[i] == v) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }

    function indexOf(uint256[] memory x, uint256 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length; ) {
            if (x[i] == v) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }

    /**
     * @dev Compute sum of all elements
     * @return s sum
     */
    function sum(int256[] memory x) internal pure returns (int256 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i];
            unchecked {
                ++i;
            }
        }
    }

    function sum(uint256[] memory x) internal pure returns (uint256 s) {
        for (uint256 i; i < x.length; ) {
            s += x[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev put the min of last p elements in array at position p.
     */
    function _sortItem(uint256[] memory x, uint256 p) private pure {
        uint256 _min = p;
        for (uint256 i = p; i < x.length; ) {
            if (x[i] < x[_min]) {
                _min = i;
            }
            unchecked {
                ++i;
            }
        }
        if (_min == p) return;
        (x[p], x[_min]) = (x[_min], x[p]);
    }

    function argSort(uint256[] memory x) internal pure returns (uint256[] memory y, uint256[] memory z) {
        y = sort(x);
        z = new uint256[](y.length);
        for (uint256 i; i < y.length; ) {
            (, uint256 w) = indexOf(x, y[i]);
            z[i] = w;
            unchecked {
                ++i;
            }
        }
    }

    function sort(uint256[] memory x) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length);
        y = populate(y, x, 0);
        for (uint256 i = 0; i < x.length - 1; i++) {
            // find the min of [i, last] and put in position i;
            _sortItem(y, i);
        }
    }

    function sortByIndexes(int256[] memory x, uint256[] memory z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length; i++) {
            y[i] = x[z[i]];
        }
    }

    function append(bytes32[] memory x, bytes32 e) internal pure returns (bytes32[] memory y) {
        y = new bytes32[](x.length + 1);
        uint256 i;
        for (i = 0; i < x.length; i++) {
            y[i] = x[i];
        }
        y[i] = e;
    }

    function append(int256[] memory x, int256 v) internal pure returns (int256[] memory y) {
        y = new int256[](x.length + 1);
        uint256 i;
        for (i = 0; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    function append(uint256[] memory x, uint256 v) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length + 1);
        uint256 i;
        for (i = 0; i < x.length; ) {
            y[i] = x[i];
            unchecked {
                ++i;
            }
        }
        y[i] = v;
    }

    function concat(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory y) {
        y = new int256[](a.length + b.length);
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

    function concat(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory y) {
        y = new uint256[](a.length + b.length);
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

    function fill(int256[] memory x, int256 v) internal pure returns (int256[] memory) {
        for (uint256 i = 0; i < x.length; i++) {
            x[i] = v;
        }
        return x;
    }

    function populate(
        uint256[] memory a,
        uint256[] memory b,
        uint256 z
    ) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < a.length; i++) {
            a[z + i] = b[i];
        }
        return a;
    }

    function at(int256[] memory x, int256 i) internal pure returns (int256) {
        int256 l = x.length.toInt256();
        if (i > 0) {
            if (i > l) revert IndexOutOfBounds();
            return x[uint256(i)];
        } else {
            if (i < -l) revert IndexOutOfBounds();
            return x[(l + i).toUint256()];
        }
    }

    function at(uint256[] memory x, int256 i) internal pure returns (uint256) {
        int256 l = x.length.toInt256();
        if (i > 0) {
            if (i > l) revert IndexOutOfBounds();
            return x[uint256(i)];
        } else {
            if (i < -l) revert IndexOutOfBounds();
            return x[(l + i).toUint256()];
        }
    }

    function slice(
        int256[] memory x,
        int256 _start,
        int256 _end
    ) internal pure returns (int256[] memory a) {
        int256 l = x.length.toInt256();
        if (_start < 0) _start = l + _start;
        if (_end <= 0) _end = l + _end;
        if (_end < _start) return new int256[](0);

        uint256 start = _start.toUint256();
        uint256 end = _end.toUint256();

        a = new int256[](end - start);
        uint256 y = 0;
        for (uint256 i = start; i < end; ) {
            a[y] = x[i];
            unchecked {
                ++i;
                ++y;
            }
        }
    }

    function subEachFrom(uint256[] memory x, uint256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = z.toInt256() - x[i].toInt256();
        }
    }

    function subEachBy(uint256[] memory x, uint256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i].toInt256() - z.toInt256();
        }
    }

    function addEachBy(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i] + z;
        }
    }

    function add(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory y) {
        y = new int256[](a.length);
        for (uint256 i = 0; i < a.length; i++) {
            y[i] = a[i] + b[i];
        }
    }

    function eachMulDivDown(
        int256[] memory x,
        int256 z,
        int256 d
    ) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = (x[i] * z) / d;
        }
    }

    function eachMulDivUp(
        int256[] memory x,
        int256 z,
        int256 d
    ) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = ((x[i] * z) / d) + 1;
        }
    }

    function eachMul(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i] * z;
        }
    }

    function eachDiv(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i] / z;
        }
    }

    function dot(int256[] memory a, int256[] memory b) internal pure returns (int256 s) {
        for (uint256 i = 0; i < a.length; i++) {
            s += a[i] * b[i];
        }
    }

    /**
     * @dev converting array of variable types
     */

    function toInt256(uint256[] memory x) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i].toInt256();
        }
    }

    function toUint256(int256[] memory x) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i].toUint256();
        }
    }
}
