pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import "../test/utils/Console.sol";

library ArrayUtil {
    using SafeCast for uint256;
    using SafeCast for int256;

    error IndexOutOfBounds();

    /**
     * @dev Returns minimal element in array
     * @return minimal
     */
    function min(int256[] memory data) internal pure returns (int256 minimal) {
        minimal = data[0];
        for (uint256 i; i < data.length; i++) {
            if (data[i] < minimal) {
                minimal = data[i];
            }
        }
    }

    function min(uint256[] memory data) internal pure returns (uint256) {
        return min(uint256ToInt256(data)).toUint256();
    }

    /**
     * @dev Returns minimal element's index
     * @return uint
     */
    function imin(uint256[] memory data) internal pure returns (uint256) {
        uint256 minimal = 0;
        for (uint256 i; i < data.length; i++) {
            if (data[i] < data[minimal]) {
                minimal = i;
            }
        }
        return minimal;
    }

    /**
     * @dev Returns maximal element in array
     * @return uint
     */
    function max(uint256[] memory data) internal pure returns (uint256) {
        uint256 maximal = data[0];
        for (uint256 i; i < data.length; i++) {
            if (data[i] > maximal) {
                maximal = data[i];
            }
        }
        return maximal;
    }

    function maximum(int256[] memory data, int256 comparedTo) internal view returns (int256[] memory array) {
        array = new int256[](data.length);
        for (uint256 i; i < data.length; i++) {
            if (data[i] > comparedTo) array[i] = data[i];
            else array[i] = comparedTo;
        }
    }

    /**
     * @dev Returns maximal element's index
     * @return uint
     */
    function imax(uint256[] memory data) internal pure returns (uint256) {
        uint256 maximal = 0;
        for (uint256 i; i < data.length; i++) {
            if (data[i] > data[maximal]) {
                maximal = i;
            }
        }
        return maximal;
    }

    /**
     * @dev Removes element at index
     * @return array new array
     */
    function remove(uint256[] memory data, uint256 index) internal view returns (uint256[] memory array) {
        if (index >= data.length) return data;
        array = new uint256[](data.length - 1);
        for (uint256 i = 0; i < data.length; i++) {
            if (i < index) array[i] = data[i];
            else if (i > index) array[i] = data[i + 1];
        }
    }

    function remove(uint8[] memory data, uint256 index) internal view returns (uint8[] memory array) {
        return uint256ToUint8(remove(uint8ToUint256(data), index));
    }

    function remove(uint64[] memory data, uint256 index) internal view returns (uint64[] memory array) {
        return uint256ToUint64(remove(uint64ToUint256(data), index));
    }

    function remove(uint80[] memory data, uint256 index) internal view returns (uint80[] memory array) {
        return uint256ToUint80(remove(uint80ToUint256(data), index));
    }

    /**
     * @dev Returns index of element
     * @return found
     * @return index
     */
    function indexOf(int256[] memory data, int256 element) internal pure returns (bool, uint256) {
        for (uint256 i; i < data.length; i++) {
            if (data[i] == element) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function indexOf(uint256[] memory data, uint256 element) internal pure returns (bool, uint256) {
        return indexOf(uint256ToInt256(data), element.toInt256());
    }

    function indexOf(uint8[] memory data, uint8 element) internal pure returns (bool, uint256) {
        return indexOf(uint8ToUint256(data), element);
    }

    /**
     * @dev Compute sum of all elements
     * @return uint
     */
    function sum(uint256[] memory data) internal pure returns (uint256) {
        uint256 S;
        for (uint256 i; i < data.length; i++) {
            S += data[i];
        }
        return S;
    }

    function sum(uint64[] memory data) internal pure returns (uint256) {
        return sum(uint64ToUint256(data));
    }

    function sum(uint80[] memory data) internal pure returns (uint256) {
        return sum(uint80ToUint256(data));
    }

    function sort_item(uint256[] memory data, uint256 pos) internal returns (bool) {
        uint256 w_min = pos;
        for (uint256 i = pos; i < data.length; i++) {
            if (data[i] < data[w_min]) {
                w_min = i;
            }
        }
        if (w_min == pos) return false;
        uint256 tmp = data[pos];
        data[pos] = data[w_min];
        data[w_min] = tmp;
        return true;
    }

    /**
     * @dev Sort the array
     */
    function sort(uint256[] memory data) internal returns (uint256[] memory sorted) {
        sorted = new uint256[](data.length);
        for (uint256 i = 0; i < data.length - 1; i++) {
            sort_item(sorted, i);
        }
    }

    function add(uint256[] memory array1, uint256 element) internal pure returns (uint256[] memory array) {
        array = new uint256[](array1.length + 1);
        uint256 i;
        for (i = 0; i < array1.length; i++) {
            array[i] = array1[i];
        }
        array[i] = element;
    }

    function concat(int256[] memory array1, int256[] memory array2) internal pure returns (int256[] memory array) {
        array = new int256[](array1.length + array2.length);
        uint256 y = 0;
        uint256 i;
        for (i = 0; i < array1.length; i++) {
            array[y] = array1[i];
            y++;
        }
        for (i = 0; i < array2.length; i++) {
            array[y] = array2[i];
            y++;
        }
    }

    function concat(uint256[] memory array1, uint256[] memory array2) internal pure returns (uint256[] memory array) {
        return int256ToUint256(concat(uint256ToInt256(array1), uint256ToInt256(array2)));
    }

    function fill(int256[] memory data, int256 value) internal pure returns (int256[] memory) {
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = value;
        }
        return data;
    }

    function populate(
        uint256[] memory array,
        uint256[] memory array1,
        uint256 from
    ) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < array1.length; i++) {
            array[from + i] = array1[i];
        }
        return array;
    }

    function at(int256[] memory data, int256 i) internal pure returns (int256) {
        int256 length = data.length.toInt256();
        if (i > 0) {
            if (i > length) revert IndexOutOfBounds();
            return data[i.toUint256()];
        } else {
            if (i < -length) revert IndexOutOfBounds();
            return data[(length + i).toUint256()];
        }
    }

    function at(uint256[] memory data, int256 i) internal pure returns (uint256) {
        return at(uint256ToInt256(data), i).toUint256();
    }

    function slice(
        int256[] memory data,
        int256 _start,
        int256 _end
    ) internal pure returns (int256[] memory array) {
        int256 length = data.length.toInt256();
        if (_start < 0) _start = length + _start;
        if (_end <= 0) _end = length + _end;
        if (_end < _start) return new int256[](0);

        uint256 start = _start.toUint256();
        uint256 end = _end.toUint256();

        array = new int256[](end - start);
        uint256 y = 0;
        for (uint256 i = start; i < end; i++) {
            array[y] = data[i];
            y++;
        }
    }

    function slice(
        uint256[] memory data,
        int256 _start,
        int256 _end
    ) internal pure returns (uint256[] memory array) {
        return int256ToUint256(slice(uint256ToInt256(data), _start, _end));
    }

    function slice(
        uint256[] memory data,
        uint256 _start,
        uint256 _end
    ) internal pure returns (uint256[] memory array) {
        return int256ToUint256(slice(uint256ToInt256(data), _start.toInt256(), _end.toInt256()));
    }

    function subEachPosFrom(uint256[] memory data, uint256 from) internal pure returns (int256[] memory array) {
        array = new int256[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            array[i] = from.toInt256() - data[i].toInt256();
        }
    }

    function subEachPosBy(uint256[] memory data, uint256 by) internal pure returns (int256[] memory array) {
        array = new int256[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            array[i] = data[i].toInt256() - by.toInt256();
        }
    }

    function add(int256[] memory array1, int256[] memory array2) internal pure returns (int256[] memory array) {
        array = new int256[](array1.length);
        for (uint256 i = 0; i < array1.length; i++) {
            array[i] = array1[i] + array2[i];
        }
    }

    function mulEachPosBy(int256[] memory data, int256 by) internal pure returns (int256[] memory array) {
        array = new int256[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            array[i] = data[i] * by;
        }
    }

    function divEachPosBy(int256[] memory data, int256 by) internal pure returns (int256[] memory array) {
        array = new int256[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            array[i] = data[i] / by;
        }
    }

    /**
     * @dev converting array of variable types
     */
    function uint8ToUint256(uint8[] memory array) internal pure returns (uint256[] memory array256) {
        array256 = new uint256[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array256[i] = uint256(array[i]);
        }
    }

    function uint64ToUint256(uint64[] memory array) internal pure returns (uint256[] memory array256) {
        array256 = new uint256[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array256[i] = uint256(array[i]);
        }
    }

    function uint80ToUint256(uint80[] memory array) internal pure returns (uint256[] memory array256) {
        array256 = new uint256[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array256[i] = uint256(array[i]);
        }
    }

    function uint256ToUint8(uint256[] memory array) internal pure returns (uint8[] memory array8) {
        array8 = new uint8[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array8[i] = array[i].toUint8();
        }
    }

    function uint256ToUint64(uint256[] memory array) internal pure returns (uint64[] memory array64) {
        array64 = new uint64[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array64[i] = array[i].toUint64();
        }
    }

    function uint256ToUint80(uint256[] memory array) internal pure returns (uint80[] memory array80) {
        array80 = new uint80[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array80[i] = array[i].toUint80();
        }
    }

    function uint256ToInt256(uint256[] memory array) internal pure returns (int256[] memory array256) {
        array256 = new int256[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array256[i] = array[i].toInt256();
        }
    }

    function int256ToUint256(int256[] memory array) internal pure returns (uint256[] memory array256) {
        array256 = new uint256[](array.length);
        for (uint256 i = 0; i < array.length; i++) {
            array256[i] = array[i].toUint256();
        }
    }
}
