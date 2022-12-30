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
        for (uint256 i; i < x.length;) {
            if (x[i] < m) {
                m = x[i];
            }
            unchecked {
                ++i;
            }
        }
    }

    function minWithIndex(int256[] memory x) internal pure returns (int256 m, uint256 idx) {
        m = x[0];
        idx = 0;
        for (uint256 i; i < x.length;) {
            if (x[i] < m) {
                m = x[i];
                idx = i;
            }
            unchecked {
                ++i;
            }
        }
    }

    function min(uint256[] memory x) internal pure returns (uint256 m) {
        m = x[0];
        for (uint256 i; i < x.length;) {
            if (x[i] < m) {
                m = x[i];
            }
            unchecked {
                ++i;
            }
        }
    }

    function minMax(uint256[] memory x) internal pure returns (uint256 min_, uint256 max_) {
        (min_, max_) = (x[0], x[0]);
        for (uint256 i; i < x.length;) {
            if (x[i] < min_) {
                min_ = x[i];
            }
            if (x[i] > max_) {
                max_ = x[i];
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Returns maximal element in array
     * @return m
     */
    function max(int256[] memory x) internal pure returns (int256 m) {
        m = x[0];
        for (uint256 i; i < x.length;) {
            if (x[i] > m) {
                m = x[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    function max(uint256[] memory x) internal pure returns (uint256 m) {
        m = x[0];
        for (uint256 i; i < x.length;) {
            if (x[i] > m) {
                m = x[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Returns maximal elements comparedTo value
     * @return y array
     */
    function maximum(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            if (x[i] > z) y[i] = x[i];
            else y[i] = z;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Removes element at index in a new unsigned int array, does not change x memory in place
     * @return y new array
     */
    function remove(uint256[] memory x, uint256 z) internal pure returns (uint256[] memory y) {
        if (z >= x.length) return x;
        y = new uint256[](x.length - 1);
        for (uint256 i; i < x.length;) {
            unchecked {
                if (i < z) y[i] = x[i];
                else if (i > z) y[i - 1] = x[i];
                ++i;
            }
        }
    }

    /**
     * @dev Removes element at index in a new signed int array, does not change x memory in place
     * @return y new array
     */
    function remove(int256[] memory x, uint256 z) internal pure returns (int256[] memory y) {
        if (z >= x.length) return x;
        y = new int256[](x.length - 1);
        for (uint256 i; i < x.length;) {
            unchecked {
                if (i < z) y[i] = x[i];
                else if (i > z) y[i - 1] = x[i];
                ++i;
            }
        }
    }

    /**
     * @dev Returns index of element
     * @return found
     * @return index
     */
    function indexOf(int256[] memory x, int256 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length;) {
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
        for (uint256 i; i < x.length;) {
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
        for (uint256 i; i < x.length;) {
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
        for (uint256 i; i < x.length;) {
            s += x[i];

            unchecked {
                ++i;
            }
        }
    }

    function sum(uint256[] memory x) internal pure returns (uint256 s) {
        for (uint256 i; i < x.length;) {
            s += x[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev put the min of last p elements in array at position p.
     */

    function argSort(uint256[] memory x) internal pure returns (uint256[] memory y, uint256[] memory ixArray) {
        ixArray = new uint256[](x.length);
        // fill in index array
        for (uint256 i; i < x.length;) {
            ixArray[i] = i;

            unchecked {
                ++i;
            }
        }
        // initialize copy of x
        y = new uint256[](x.length);
        populate(y, x, 0);
        // sort
        quickSort(y, int256(0), int256(y.length - 1), ixArray);
    }

    function sort(uint256[] memory x) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length);
        populate(y, x, 0);
        quickSort(y, int256(0), int256(y.length - 1));
    }

    /*
    @dev quicksort implementation, sorts arr input IN PLACE
    */
    function quickSort(uint256[] memory arr, int256 left, int256 right) internal pure {
        if (left == right) return;
        int256 i = left;
        int256 j = right;
        unchecked {
            uint256 pivot = arr[uint256(left + (right - left) / 2)];
            while (i <= j) {
                while (arr[uint256(i)] < pivot) {
                    ++i;
                }
                while (pivot < arr[uint256(j)]) {
                    --j;
                }
                if (i <= j) {
                    (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                    ++i;
                    --j;
                }
            }
        }
        if (left < j) quickSort(arr, left, j);
        if (i < right) quickSort(arr, i, right);
    }

    /*
    @dev quicksort implementation with indexes, sorts input arr and indexArray IN PLACE
    */
    function quickSort(uint256[] memory arr, int256 left, int256 right, uint256[] memory indexArray) internal pure {
        if (left == right) return;
        int256 i = left;
        int256 j = right;
        unchecked {
            uint256 pivot = arr[uint256(left + (right - left) / 2)];
            while (i <= j) {
                while (arr[uint256(i)] < pivot) {
                    ++i;
                }
                while (pivot < arr[uint256(j)]) {
                    --j;
                }
                if (i <= j) {
                    (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                    (indexArray[uint256(i)], indexArray[uint256(j)]) = (indexArray[uint256(j)], indexArray[uint256(i)]);
                    ++i;
                    --j;
                }
            }
            if (left < j) quickSort(arr, left, j, indexArray);
            if (i < right) quickSort(arr, i, right, indexArray);
        }
    }

    /**
     *  sort functions for int ***
     */

    function argSort(int256[] memory x) internal pure returns (int256[] memory y, uint256[] memory ixArray) {
        ixArray = new uint256[](x.length);
        // fill in index array
        for (uint256 i; i < x.length;) {
            ixArray[i] = i;

            unchecked {
                ++i;
            }
        }
        // initialize copy of x
        y = new int256[](x.length);
        populate(y, x, 0);
        // sort
        quickSort(y, int256(0), int256(y.length - 1), ixArray);
    }

    function sort(int256[] memory x) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        populate(y, x, 0);
        quickSort(y, int256(0), int256(y.length - 1));
    }

    // quicksort implementation, sorts arr in place
    function quickSort(int256[] memory arr, int256 left, int256 right) internal pure {
        if (left == right) return;
        int256 i = left;
        int256 j = right;
        unchecked {
            int256 pivot = arr[uint256(left + (right - left) / 2)];

            while (i <= j) {
                while (arr[uint256(i)] < pivot) {
                    ++i;
                }
                while (pivot < arr[uint256(j)]) {
                    --j;
                }
                if (i <= j) {
                    (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                    ++i;
                    --j;
                }
            }
        }
        if (left < j) quickSort(arr, left, j);
        if (i < right) quickSort(arr, i, right);
    }

    // quicksort implementation with indexes, sorts arr and indexArray in place
    function quickSort(int256[] memory arr, int256 left, int256 right, uint256[] memory indexArray) internal pure {
        if (left == right) return;
        int256 i = left;
        int256 j = right;
        unchecked {
            int256 pivot = arr[uint256(left + (right - left) / 2)];
            while (i <= j) {
                while (arr[uint256(i)] < pivot) {
                    ++i;
                }
                while (pivot < arr[uint256(j)]) {
                    --j;
                }
                if (i <= j) {
                    (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
                    (indexArray[uint256(i)], indexArray[uint256(j)]) = (indexArray[uint256(j)], indexArray[uint256(i)]);
                    ++i;
                    --j;
                }
            }
        }
        if (left < j) quickSort(arr, left, j, indexArray);
        if (i < right) quickSort(arr, i, right, indexArray);
    }

    /**
     * End Sort Functions for Int ******
     */

    function sortByIndexes(int256[] memory x, uint256[] memory z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[z[i]];

            unchecked {
                ++i;
            }
        }
    }

    function append(bytes32[] memory x, bytes32 e) internal pure returns (bytes32[] memory y) {
        y = new bytes32[](x.length + 1);
        uint256 i;
        for (i; i < x.length;) {
            y[i] = x[i];

            unchecked {
                ++i;
            }
        }
        y[i] = e;
    }

    function append(int256[] memory x, int256 v) internal pure returns (int256[] memory y) {
        y = new int256[](x.length + 1);
        uint256 i;
        for (i; i < x.length;) {
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
        for (i; i < x.length;) {
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

    function concat(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory y) {
        y = new uint256[](a.length + b.length);
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

    /*
    @dev this function modifies memory x IN PLACE. Fills x with value v
    */
    function fill(int256[] memory x, int256 v) internal pure {
        for (uint256 i; i < x.length;) {
            x[i] = v;

            unchecked {
                ++i;
            }
        }
    }

    /*
    @dev modifies memory a IN PLACE. Populates a starting at index z with values from b.
    */
    function populate(uint256[] memory a, uint256[] memory b, uint256 z) internal pure {
        for (uint256 i; i < a.length;) {
            a[z + i] = b[i];

            unchecked {
                ++i;
            }
        }
    }

    /*
    @dev modifies memory a IN PLACE. Populates a starting at index z with values from b.
    */
    function populate(int256[] memory a, int256[] memory b, uint256 z) internal pure {
        for (uint256 i; i < a.length;) {
            a[z + i] = b[i];

            unchecked {
                ++i;
            }
        }
    }

    function at(int256[] memory x, int256 i) internal pure returns (int256) {
        int256 len = x.length.toInt256();
        if (i > 0) {
            if (i > len) revert IndexOutOfBounds();
            return x[uint256(i)];
        } else {
            if (i < -len) revert IndexOutOfBounds();
            return x[(len + i).toUint256()];
        }
    }

    function at(uint256[] memory x, int256 i) internal pure returns (uint256) {
        int256 len = x.length.toInt256();
        if (i > 0) {
            if (i > len) revert IndexOutOfBounds();
            return x[uint256(i)];
        } else {
            if (i < -len) revert IndexOutOfBounds();
            return x[(len + i).toUint256()];
        }
    }

    function slice(int256[] memory x, int256 _start, int256 _end) internal pure returns (int256[] memory a) {
        int256 len = x.length.toInt256();
        if (_start < 0) _start = len + _start;
        if (_end <= 0) _end = len + _end;
        if (_end < _start) return new int256[](0);

        uint256 start = _start.toUint256();
        uint256 end = _end.toUint256();

        a = new int256[](end - start);
        uint256 y = 0;
        for (uint256 i = start; i < end;) {
            a[y] = x[i];

            unchecked {
                ++i;
                ++y;
            }
        }
    }

    function subEachFrom(uint256[] memory x, uint256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = z.toInt256() - x[i].toInt256();

            unchecked {
                ++i;
            }
        }
    }

    function subEachBy(uint256[] memory x, uint256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i].toInt256() - z.toInt256();

            unchecked {
                ++i;
            }
        }
    }

    function addEachBy(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i] + z;

            unchecked {
                ++i;
            }
        }
    }

    function add(int256[] memory a, int256[] memory b) internal pure returns (int256[] memory y) {
        y = new int256[](a.length);
        for (uint256 i; i < a.length;) {
            y[i] = a[i] + b[i];

            unchecked {
                i++;
            }
        }
    }

    function eachMulDivDown(int256[] memory x, int256 z, int256 d) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = (x[i] * z) / d;

            unchecked {
                ++i;
            }
        }
    }

    function eachMulDivUp(int256[] memory x, int256 z, int256 d) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = ((x[i] * z) / d) + 1;

            unchecked {
                ++i;
            }
        }
    }

    function eachMul(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i] * z;

            unchecked {
                ++i;
            }
        }
    }

    function eachDiv(int256[] memory x, int256 z) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i] / z;

            unchecked {
                ++i;
            }
        }
    }

    function dot(int256[] memory a, int256[] memory b) internal pure returns (int256 s) {
        for (uint256 i; i < a.length;) {
            s += a[i] * b[i];

            unchecked {
                ++i;
            }
        }
    }

    function dot(uint256[] memory a, int256[] memory b) internal pure returns (int256 s) {
        for (uint256 i; i < a.length;) {
            s += int256(a[i]) * b[i];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev converting array of variable types
     */

    function toInt256(uint256[] memory x) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i].toInt256();

            unchecked {
                ++i;
            }
        }
    }

    function toUint256(int256[] memory x) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length);
        for (uint256 i; i < x.length;) {
            y[i] = x[i].toUint256();

            unchecked {
                ++i;
            }
        }
    }
}
