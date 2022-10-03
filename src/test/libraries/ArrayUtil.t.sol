// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import {ArrayUtil} from "../../libraries/ArrayUtil.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

import "../../test/utils/Console.sol";

/**
 * Basic tests
 */
contract ArrayUtilTest is Test {
    using ArrayUtil for uint256[];
    using ArrayUtil for int256[];

    function testConcat() public {
        uint256[] memory array1 = new uint256[](0);
        array1 = array1.add(1);
        array1 = array1.add(2);

        assertEq(array1.length, 2);
        assertEq(array1[0], 1);
        assertEq(array1[1], 2);

        uint256[] memory array2 = new uint256[](0);
        array2 = array2.add(3);
        array2 = array2.add(4);
        array1 = array1.concat(array2);

        assertEq(array1.length, 4);
        assertEq(array1[0], 1);
        assertEq(array1[1], 2);
        assertEq(array1[2], 3);
        assertEq(array1[3], 4);

        array1 = new uint256[](0);
        array1 = array1.add(1);
        array2 = new uint256[](0);
        array1 = array1.concat(array2);

        assertEq(array1.length, 1);
        assertEq(array1[0], 1);
    }

    function testNegativeIndexSelector() public {
        uint256[] memory array1 = new uint256[](0);
        array1 = array1.add(1);
        array1 = array1.add(2);
        array1 = array1.add(3);

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
}
