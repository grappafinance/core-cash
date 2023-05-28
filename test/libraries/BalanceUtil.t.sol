// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {BalanceUtil} from "src/libraries/BalanceUtil.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";
import "src/config/types.sol";

contract BalanceUtilTester {
    Balance[] public balances;

    function append(Balance[] memory x, Balance memory v) external pure returns (Balance[] memory) {
        Balance[] memory result = BalanceUtil.append(x, v);
        return result;
    }

    function find(Balance[] memory x, uint8 v) external pure returns (bool, Balance memory, uint256) {
        (bool f, Balance memory b, uint256 i) = BalanceUtil.find(x, v);
        return (f, b, i);
    }

    function indexOf(Balance[] memory x, uint8 v) external pure returns (bool, uint256) {
        (bool f, uint256 i) = BalanceUtil.indexOf(x, v);
        return (f, i);
    }

    function add(Balance memory b) external {
        balances.push(b);
    }

    function remove(uint256 y) external {
        BalanceUtil.remove(balances, y);
    }

    function isEmpty(Balance[] memory x) external pure returns (bool) {
        bool result = BalanceUtil.isEmpty(x);
        return result;
    }
}

/**
 * @dev library test for BalanceUtils
 */
contract BalanceUtilTest is Test {
    uint256 public constant base = UNIT;

    BalanceUtilTester tester;

    function setUp() public {
        tester = new BalanceUtilTester();
    }

    function testAppend() public {
        Balance[] memory arr = new Balance[](0);
        Balance memory element = Balance(1, 1000_000);

        Balance[] memory newArr = tester.append(arr, element);
        assertEq(newArr.length, 1);
        assertEq(newArr[0].collateralId, 1);
        assertEq(newArr[0].amount, 1000_000);

        Balance memory element2 = Balance(2, 2000_000);

        // test we can override old array
        newArr = tester.append(newArr, element2);
        assertEq(newArr.length, 2);
        assertEq(newArr[0].collateralId, 1);
        assertEq(newArr[0].amount, 1000_000);
        assertEq(newArr[1].collateralId, 2);
        assertEq(newArr[1].amount, 2000_000);
    }

    function testFind() public {
        Balance[] memory defaultArr = _getDefaultBalanceArray();
        (bool found, Balance memory b, uint256 index) = tester.find(defaultArr, 1);
        assertEq(found, true);
        assertEq(b.amount, 1000_000);
        assertEq(index, 0);

        (bool found2, Balance memory b2, uint256 index2) = tester.find(defaultArr, 2);
        assertEq(found2, true);
        assertEq(b2.amount, 2000_000);
        assertEq(index2, 1);

        // element that does not exist
        (bool found6, Balance memory b6, uint256 index6) = tester.find(defaultArr, 6);
        assertEq(found6, false);
        assertEq(b6.amount, 0);
        assertEq(index6, 5); // index that points to nothing
    }

    function testIndexOf() public {
        Balance[] memory defaultArr = _getDefaultBalanceArray();
        (bool found, uint256 index) = tester.indexOf(defaultArr, 1);
        assertEq(found, true);
        assertEq(index, 0);

        (bool found4, uint256 index4) = tester.indexOf(defaultArr, 4);
        assertEq(found4, true);
        assertEq(index4, 3);

        // element that does not exist
        (bool found6, uint256 index6) = tester.indexOf(defaultArr, 6);
        assertEq(found6, false);
        assertEq(index6, 5); // index that points to nothing
    }

    function testIsEmpty() public {
        Balance[] memory defaultArr = _getDefaultBalanceArray();
        bool empty = tester.isEmpty(defaultArr);
        assertEq(empty, false);
    }

    function testRemoveStorage() public {
        Balance memory b = Balance(1, 1000_000);
        tester.add(b);
        (uint8 id, uint80 amount) = tester.balances(0);
        assertEq(id, 1);
        assertEq(amount, 1000_000);

        // remove non existant index: does not affect storage
        tester.remove(1);
        (uint8 idAfter, uint80 amountAfter) = tester.balances(0);
        assertEq(idAfter, 1);
        assertEq(amountAfter, 1000_000);

        // remove index 0
        tester.remove(0);
        // cannot access this index
        vm.expectRevert();
        tester.balances(0);
    }

    function _getDefaultBalanceArray() internal pure returns (Balance[] memory) {
        Balance[] memory arr = new Balance[](5);
        arr[0] = Balance(1, 1000_000);
        arr[1] = Balance(2, 2000_000);
        arr[2] = Balance(3, 3000_000);
        arr[3] = Balance(4, 4000_000);
        arr[4] = Balance(5, 5000_000);
        return arr;
    }
}
