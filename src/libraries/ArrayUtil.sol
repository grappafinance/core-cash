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
        for (uint256 i; i < x.length; i++) {
            if (x[i] < m) {
                m = x[i];
            }
        }
    }

    function min(uint256[] memory x) internal pure returns (uint256) {
        return min(toInt256(x)).toUint256();
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

    function max(uint256[] memory x) internal pure returns (uint256) {
        return max(toInt256(x)).toUint256();
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
     * @dev Removes element at index
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

    // function remove(uint8[] memory x, uint256 i) internal pure returns (uint8[] memory) {
    //     return toUint8(remove(toUint256(x), i));
    // }

    // function remove(uint64[] memory x, uint256 i) internal pure returns (uint64[] memory) {
    //     return toUint64(remove(toUint256(x), i));
    // }

    // function remove(uint80[] memory x, uint256 i) internal pure returns (uint80[] memory) {
    //     return toUint80(remove(toUint256(x), i));
    // }

    /**
     * @dev Returns index of element
     * @return found
     * @return index
     */
    function indexOf(int256[] memory x, int256 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length; i++) {
            if (x[i] == v) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function indexOf(bytes32[] memory x, bytes32 v) internal pure returns (bool, uint256) {
        for (uint256 i; i < x.length; i++) {
            if (x[i] == v) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function indexOf(uint256[] memory x, uint256 v) internal pure returns (bool, uint256) {
        return indexOf(toInt256(x), v.toInt256());
    }

    // function indexOf(uint8[] memory x, uint8 v) internal pure returns (bool, uint256) {
    //     return indexOf(toUint256(x), v);
    // }

    /**
     * @dev Compute sum of all elements
     * @return s sum
     */
    function sum(int256[] memory x) internal pure returns (int256 s) {
        for (uint256 i; i < x.length; i++) {
            s += x[i];
        }
    }

    function sum(uint256[] memory x) internal pure returns (uint256 s) {
        return sum(toInt256(x)).toUint256();
    }

    // function sum(uint64[] memory x) internal pure returns (uint256) {
    //     return sum(toUint256(x));
    // }

    // function sum(uint80[] memory x) internal pure returns (uint256) {
    //     return sum(toUint256(x));
    // }

    function _sortItem(uint256[] memory x, uint256 p) internal pure returns (uint256[] memory) {
        uint256 w_min = p;
        for (uint256 i = p; i < x.length; i++) {
            if (x[i] < x[w_min]) {
                w_min = i;
            }
        }
        if (w_min == p) return x;
        uint256 tmp = x[p];
        x[p] = x[w_min];
        x[w_min] = tmp;
        return x;
    }

    function argSort(uint256[] memory x) internal pure returns (uint256[] memory y, uint256[] memory z) {
        y = sort(x);
        z = new uint256[](y.length);
        for (uint256 i; i < y.length;) {
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
            y = _sortItem(y, i);
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
        for (i = 0; i < x.length; i++) {
            y[i] = x[i];
        }
        y[i] = v;
    }

    function append(uint256[] memory x, uint256 v) internal pure returns (uint256[] memory) {
        return toUint256(append(toInt256(x), v.toInt256()));
    }

    // function append(uint8[] memory x, uint8 v) internal pure returns (uint8[] memory) {
    //     return toInt8(append(toInt256(x), int256(int8(v))));
    // }

    // function append(uint80[] memory x, uint80 v) internal pure returns (uint80[] memory) {
    //     return toUint80(append(toInt256(x), int256(int80(v))));
    // }

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

    function concat(uint256[] memory a, uint256[] memory b) internal pure returns (uint256[] memory array) {
        return toUint256(concat(toInt256(a), toInt256(b)));
    }

    // function concat(uint64[] memory a, uint64[] memory b) internal pure returns (uint64[] memory array) {
    //     return toUint64(concat(toInt256(a), toInt256(b)));
    // }

    function fill(int256[] memory x, int256 v) internal pure returns (int256[] memory) {
        for (uint256 i = 0; i < x.length; i++) {
            x[i] = v;
        }
        return x;
    }

    function populate(
        int256[] memory a,
        int256[] memory b,
        uint256 z
    ) internal pure returns (int256[] memory) {
        for (uint256 i = 0; i < a.length; i++) {
            a[z + i] = b[i];
        }
        return a;
    }

    function populate(
        uint256[] memory a,
        uint256[] memory b,
        uint256 z
    ) internal pure returns (uint256[] memory) {
        uint256[] memory x = toUint256(populate(toInt256(a), toInt256(b), z));
        for (uint256 i = 0; i < a.length; i++) {
            a[i] = x[i];
        }
        return a;
    }

    function at(int256[] memory x, int256 i) internal pure returns (int256) {
        int256 l = x.length.toInt256();
        if (i > 0) {
            if (i > l) revert IndexOutOfBounds();
            return x[i.toUint256()];
        } else {
            if (i < -l) revert IndexOutOfBounds();
            return x[(l + i).toUint256()];
        }
    }

    function at(uint256[] memory x, int256 i) internal pure returns (uint256) {
        return at(toInt256(x), i).toUint256();
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
        for (uint256 i = start; i < end; i++) {
            a[y] = x[i];
            ++y;
        }
    }

    function slice(
        uint256[] memory x,
        int256 y,
        int256 z
    ) internal pure returns (uint256[] memory) {
        return toUint256(slice(toInt256(x), y, z));
    }

    function slice(
        uint256[] memory x,
        uint256 y,
        uint256 z
    ) internal pure returns (uint256[] memory) {
        return toUint256(slice(toInt256(x), y.toInt256(), z.toInt256()));
    }

    // function map(int256[] memory self, function(int256) pure returns (int256) f)
    //     internal
    //     pure
    //     returns (int256[] memory r)
    // {
    //     r = new int256[](self.length);
    //     for (uint256 i = 0; i < self.length; i++) {
    //         r[i] = f(self[i]);
    //     }
    // }

    // function map2(
    //     int256[] memory x,
    //     function(int256, int256) pure returns (int256) f,
    //     int256 y
    // ) internal pure returns (int256[] memory r) {
    //     r = new int256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         r[i] = f(x[i], y);
    //     }
    // }

    // function reduce(uint256[] memory self, function(uint256, uint256) pure returns (uint256) f)
    //     internal
    //     pure
    //     returns (uint256 r)
    // {
    //     r = self[0];
    //     for (uint256 i = 1; i < self.length; i++) {
    //         r = f(r, self[i]);
    //     }
    // }

    // function range(uint256 length) internal pure returns (uint256[] memory r) {
    //     r = new uint256[](length);
    //     for (uint256 i = 0; i < r.length; i++) {
    //         r[i] = i;
    //     }
    // }

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

    // function toInt8(int256[] memory x) internal pure returns (uint8[] memory y) {
    //     y = new uint8[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint256().toUint8();
    //     }
    // }

    // function toUint8(uint256[] memory x) internal pure returns (uint8[] memory y) {
    //     y = new uint8[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint8();
    //     }
    // }

    // function toUint64(uint256[] memory x) internal pure returns (uint64[] memory y) {
    //     y = new uint64[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint64();
    //     }
    // }

    // function toUint64(int256[] memory x) internal pure returns (uint64[] memory y) {
    //     y = new uint64[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint256().toUint64();
    //     }
    // }

    // function toInt80(uint80[] memory x) internal pure returns (int80[] memory y) {
    //     y = new int80[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = int80(x[i]);
    //     }
    // }

    // function toUint80(int80[] memory x) internal pure returns (uint80[] memory y) {
    //     y = new uint80[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = uint80(x[i]);
    //     }
    // }

    // function toUint80(uint256[] memory x) internal pure returns (uint80[] memory y) {
    //     y = new uint80[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint80();
    //     }
    // }

    // function toUint80(int256[] memory x) internal pure returns (uint80[] memory y) {
    //     y = new uint80[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = x[i].toUint256().toUint80();
    //     }
    // }

    // function toInt256(uint8[] memory x) internal pure returns (int256[] memory y) {
    //     y = new int256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = int256(int8(x[i]));
    //     }
    // }

    // function toInt256(uint64[] memory x) internal pure returns (int256[] memory y) {
    //     y = new int256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = int256(int64(x[i]));
    //     }
    // }

    // function toInt256(uint80[] memory x) internal pure returns (int256[] memory y) {
    //     y = new int256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = int256(int80(x[i]));
    //     }
    // }

    function toInt256(uint256[] memory x) internal pure returns (int256[] memory y) {
        y = new int256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i].toInt256();
        }
    }

    // function toUint256(uint8[] memory x) internal pure returns (uint256[] memory y) {
    //     y = new uint256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = uint256(x[i]);
    //     }
    // }

    // function toUint256(uint64[] memory x) internal pure returns (uint256[] memory y) {
    //     y = new uint256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = uint256(x[i]);
    //     }
    // }

    // function toUint256(uint80[] memory x) internal pure returns (uint256[] memory y) {
    //     y = new uint256[](x.length);
    //     for (uint256 i = 0; i < x.length; i++) {
    //         y[i] = uint256(x[i]);
    //     }
    // }

    function toUint256(int256[] memory x) internal pure returns (uint256[] memory y) {
        y = new uint256[](x.length);
        for (uint256 i = 0; i < x.length; i++) {
            y[i] = x[i].toUint256();
        }
    }
}
