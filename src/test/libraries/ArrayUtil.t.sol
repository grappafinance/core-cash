// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import {ArrayUtil} from "../../libraries/ArrayUtil.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

/**
 * Basic tests
 */
contract ArrayUtilTest is Test {
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];

    function testConcat() public {
        uint256[] memory array1 = new uint256[](0);
        array1 = array1.append(1);
        array1 = array1.append(2);

        assertEq(array1.length, 2);
        assertEq(array1[0], 1);
        assertEq(array1[1], 2);

        uint256[] memory array2 = new uint256[](0);
        array2 = array2.append(3);
        array2 = array2.append(4);
        array1 = array1.concat(array2);

        assertEq(array1.length, 4);
        assertEq(array1[0], 1);
        assertEq(array1[1], 2);
        assertEq(array1[2], 3);
        assertEq(array1[3], 4);

        array1 = new uint256[](0);
        array1 = array1.append(1);
        array2 = new uint256[](0);
        array1 = array1.concat(array2);

        assertEq(array1.length, 1);
        assertEq(array1[0], 1);
    }

    function testNegativeIndexSelector() public {
        uint256[] memory array1 = new uint256[](0);
        array1 = array1.append(1);
        array1 = array1.append(2);
        array1 = array1.append(3);

        uint256 element;

        element = array1.at(-1);
        assertEq(element, 3);

        vm.expectRevert(ArrayUtil.IndexOutOfBounds.selector);
        array1.at(-10);
    }

    function testPopulate() public {
        uint256[] memory array1 = new uint256[](2);

        uint256[] memory array2 = new uint256[](2);
        array2[0] = 1;
        array2[1] = 2;

        array1.populate(array2, 0);
        assertEq(array1.length, 2);
        assertEq(array1[0], 1);
        assertEq(array1[1], 2);

        vm.expectRevert(stdError.indexOOBError);
        array1.populate(array2, 1);
    }

    function testSlice() public {
        int256[] memory array = new int256[](5);
        array[0] = 1;
        array[1] = 2;
        array[2] = 3;
        array[3] = 4;
        array[4] = 5;

        int256[] memory slice = array.slice(2, 4);
        assertEq(slice.length, 2);
        assertEq(slice[0], 3);
        assertEq(slice[1], 4);

        slice = array.slice(1, -1);
        assertEq(slice.length, 3);
        assertEq(slice[0], 2);
        assertEq(slice[1], 3);
        assertEq(slice[2], 4);

        slice = array.slice(-3, -1);
        assertEq(slice.length, 2);
        assertEq(slice[0], 3);
        assertEq(slice[1], 4);

        slice = array.slice(2, 0);
        assertEq(slice.length, 3);
        assertEq(slice[0], 3);
        assertEq(slice[1], 4);
        assertEq(slice[2], 5);

        slice = array.slice(-1, -2);
        assertEq(slice.length, 0);
    }

    function testSort() public {
        uint256[] memory array = new uint256[](5);
        array[0] = 400;
        array[1] = 200;
        array[2] = 100;
        array[3] = 500;
        array[4] = 300;

        uint256[] memory sorted = array.sort();
        assertEq(sorted.length, 5);
        assertEq(sorted[0], 100);
        assertEq(sorted[1], 200);
        assertEq(sorted[2], 300);
        assertEq(sorted[3], 400);
        assertEq(sorted[4], 500);
    }

    function testSortDups() public {
        uint256[] memory array = new uint256[](6);
        array[0] = 1;
        array[1] = 1;
        array[2] = 1;
        array[3] = 0;
        array[4] = 3;
        array[5] = 3;

        uint256[] memory sorted = array.sort();
        assertEq(sorted.length, 6);
        assertEq(sorted[0], 0);
        assertEq(sorted[1], 1);
        assertEq(sorted[2], 1);
        assertEq(sorted[3], 1);
        assertEq(sorted[4], 3);
        assertEq(sorted[5], 3);
    }

    function testArgSort() public {
        uint256[] memory array = new uint256[](5);
        array[0] = 400;
        array[1] = 200;
        array[2] = 100;
        array[3] = 500;
        array[4] = 300;

        (uint256[] memory sorted, uint256[] memory indexes) = array.argSort();
        assertEq(sorted.length, 5);
        assertEq(sorted[0], 100);
        assertEq(sorted[1], 200);
        assertEq(sorted[2], 300);
        assertEq(sorted[3], 400);
        assertEq(sorted[4], 500);

        assertEq(indexes.length, 5);
        assertEq(indexes[0], 2);
        assertEq(indexes[1], 1);
        assertEq(indexes[2], 4);
        assertEq(indexes[3], 0);
        assertEq(indexes[4], 3);
    }

    function testArgSortDups() public {
        uint256[] memory array = new uint256[](5);
        array[0] = 4;
        array[1] = 1;
        array[2] = 1;
        array[3] = 1;
        array[4] = 3;

        (uint256[] memory sorted, uint256[] memory indexes) = array.argSort();
        assertEq(sorted.length, 5);
        assertEq(sorted[0], 1);
        assertEq(sorted[1], 1);
        assertEq(sorted[2], 1);
        assertEq(sorted[3], 3);
        assertEq(sorted[4], 4);

        assertEq(indexes.length, 5);
        assertEq(indexes[0], 2);
        assertEq(indexes[1], 3);
        assertEq(indexes[2], 1);
        assertEq(indexes[3], 4);
        assertEq(indexes[4], 0);
    }

    function testArgSortDupsInt() public {
        /// this implicitly tests sort and sort dups too
        int256[] memory array = new int256[](5);
        array[0] = 4;
        array[1] = -1;
        array[2] = -1;
        array[3] = -1;
        array[4] = 3;

        (int256[] memory sorted, uint256[] memory indexes) = array.argSort();
        assertEq(sorted.length, 5);
        assertEq(sorted[0], -1);
        assertEq(sorted[1], -1);
        assertEq(sorted[2], -1);
        assertEq(sorted[3], 3);
        assertEq(sorted[4], 4);

        assertEq(indexes.length, 5);

        assertEq(indexes[0], 2);
        assertEq(indexes[1], 3);
        assertEq(indexes[2], 1);
        assertEq(indexes[3], 4);
        assertEq(indexes[4], 0);
    }

    function testArgSortDupsEvenItems() public {
        uint256[] memory array = new uint256[](6);
        array[0] = 4;
        array[1] = 1;
        array[2] = 1;
        array[3] = 1;
        array[4] = 3;
        array[5] = 3;

        (uint256[] memory sorted, uint256[] memory indexes) = array.argSort();
        assertEq(sorted.length, 6);
        assertEq(sorted[0], 1);
        assertEq(sorted[1], 1);
        assertEq(sorted[2], 1);
        assertEq(sorted[3], 3);
        assertEq(sorted[4], 3);
        assertEq(sorted[5], 4);

        assertEq(indexes.length, 6);

        assertEq(indexes[0], 2);
        assertEq(indexes[1], 3);
        assertEq(indexes[2], 1);
        assertEq(indexes[3], 4);
        assertEq(indexes[4], 5);
        assertEq(indexes[5], 0);
    }

    function testSortByIndexes() public {
        uint256[] memory array = new uint256[](5);
        array[0] = 400;
        array[1] = 200;
        array[2] = 100;
        array[3] = 500;
        array[4] = 300;

        int256[] memory array2 = new int256[](5);
        array2[0] = 400;
        array2[1] = 200;
        array2[2] = 100;
        array2[3] = 500;
        array2[4] = 300;

        (, uint256[] memory indexes) = array.argSort();

        int256[] memory sortedByIndex = array2.sortByIndexes(indexes);
        assertEq(sortedByIndex.length, 5);
        assertEq(sortedByIndex[0], 100);
        assertEq(sortedByIndex[1], 200);
        assertEq(sortedByIndex[2], 300);
        assertEq(sortedByIndex[3], 400);
        assertEq(sortedByIndex[4], 500);
    }

    function testSortByIndexesEvenItems() public {
        uint256[] memory array = new uint256[](6);
        array[0] = 400;
        array[1] = 200;
        array[2] = 100;
        array[3] = 500;
        array[4] = 200;
        array[5] = 300;

        int256[] memory array2 = new int256[](6);
        array2[0] = 400;
        array2[1] = 200;
        array2[2] = 100;
        array2[3] = 500;
        array2[4] = 200;
        array2[5] = 300;

        (, uint256[] memory indexes) = array.argSort();

        int256[] memory sortedByIndex = array2.sortByIndexes(indexes);
        assertEq(sortedByIndex.length, 6);
        assertEq(sortedByIndex[0], 100);
        assertEq(sortedByIndex[1], 200);
        assertEq(sortedByIndex[2], 200);
        assertEq(sortedByIndex[3], 300);
        assertEq(sortedByIndex[4], 400);
        assertEq(sortedByIndex[5], 500);
    }
}
