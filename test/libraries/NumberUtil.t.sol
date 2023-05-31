// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/libraries/NumberUtil.sol";

/**
 * @dev for current `forge coverage` to wrok, i needs to call an external contract then invoke internal library
 */
contract NumberUtilsTester {
    function convertDecimals(uint256 amount, uint8 from, uint8 to) external pure returns (uint256) {
        uint256 res = NumberUtil.convertDecimals(amount, from, to);
        return res;
    }

    function mul(uint256 x, uint256 y) external pure returns (uint256) {
        uint256 res = NumberUtil.mul(x, y);
        return res;
    }
}

contract DecimalMathTest is Test {
    NumberUtilsTester tester;

    function setUp() public {
        tester = new NumberUtilsTester();
    }

    function testConversionSameDecimals() public {
        uint256 amount = 1 ether;
        uint256 result = tester.convertDecimals(amount, 18, 18);
        assertEq(result, amount);
    }

    function testConversionScaleUp() public {
        uint256 amount = 1 ether;
        uint256 result = tester.convertDecimals(amount, 18, 20);
        assertEq(result, 100 ether);

        uint256 result2 = tester.convertDecimals(1e6, 6, 18);
        assertEq(result2, amount);
    }

    function testConversionScaleDown() public {
        uint256 amount = 1 ether;
        uint256 result = tester.convertDecimals(amount, 18, 16);
        assertEq(result, 0.01 ether);

        uint256 result2 = tester.convertDecimals(amount, 18, 6);
        assertEq(result2, 1e6);
    }

    function testMul(uint256 x, uint256 y) public {
        vm.assume(x < type(uint128).max);
        vm.assume(y < type(uint128).max);
        assertEq(x * y, tester.mul(x, y));
    }

    function testMulOverflowInUncheck() public {
        vm.expectRevert();
        unchecked {
            tester.mul(type(uint256).max, 5);
        }
    }
}
