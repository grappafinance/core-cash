// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MoneynessLib} from "../../libraries/MoneynessLib.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

contract MoneynessLibTester {
    function getCallCashValue(uint256 spot, uint256 strikePrice) external pure returns (uint256) {
        uint256 result = MoneynessLib.getCallCashValue(spot, strikePrice);
        return result;
    }

    function getPutCashValue(uint256 spot, uint256 strikePrice) external pure returns (uint256) {
        uint256 result = MoneynessLib.getPutCashValue(spot, strikePrice);
        return result;
    }

    function getCashValueDebitCallSpread(uint256 spot, uint256 longStrike, uint256 shortStrike) external pure returns (uint256) {
        uint256 result = MoneynessLib.getCashValueDebitCallSpread(spot, longStrike, shortStrike);
        return result;
    }

    function getCashValueDebitPutSpread(uint256 spot, uint256 longStrike, uint256 shortStrike) external pure returns (uint256) {
        uint256 result = MoneynessLib.getCashValueDebitPutSpread(spot, longStrike, shortStrike);
        return result;
    }
}

/**
 * Basic tests
 */
contract MoneynessLibTest is Test {
    uint256 public constant base = UNIT;

    MoneynessLibTester tester;

    function setUp() public {
        tester = new MoneynessLibTester();
    }

    function testCallCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = tester.getCallCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot < strike
        spot = 2800 * base;
        cash = tester.getCallCashValue(spot, strike);
        assertEq(cash, 0);

        // spot = strike
        spot = 2900 * base;
        cash = tester.getCallCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testPutCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = tester.getPutCashValue(spot, strike);
        assertEq(cash, 0);

        // spot < strike
        spot = 2800 * base;
        cash = tester.getPutCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot = strike
        spot = 2900 * base;
        cash = tester.getPutCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testCallSpreadCashValue() public {
        uint256 spot = 3000 * base;
        uint256 longStrike = 3200 * base;
        uint256 shortStrike = 3400 * base;
        uint256 cash = tester.getCashValueDebitCallSpread(spot, longStrike, shortStrike);
        assertEq(cash, 0);

        // spot is between 2 strikes
        spot = 3300 * base;
        cash = tester.getCashValueDebitCallSpread(spot, longStrike, shortStrike);
        assertEq(cash, 100 * base);

        // spot is higher than both, cash should be capped
        spot = 4000 * base;
        cash = tester.getCashValueDebitCallSpread(spot, longStrike, shortStrike);
        assertEq(cash, 200 * base);
    }

    function testCallSpreadCashValueUnderflow() public {
        // the function assume input to have longStrike < shortStrike
        // if this is not the case, the result will be wrong
        uint256 spot = 3600 * base;
        uint256 longStrike = 3400 * base;
        uint256 shortStrike = 3200 * base;
        uint256 cash = tester.getCashValueDebitCallSpread(spot, longStrike, shortStrike);
        // underflow
        assertEq(cash, type(uint256).max - (200 * base) + 1);
    }

    function testPutSpreadCashValue() public {
        uint256 spot = 3000 * base;
        uint256 longStrike = 2800 * base;
        uint256 shortStrike = 2600 * base;
        uint256 cash = tester.getCashValueDebitPutSpread(spot, longStrike, shortStrike);
        assertEq(cash, 0);

        // spot is between 2 strikes
        spot = 2700 * base;
        cash = tester.getCashValueDebitPutSpread(spot, longStrike, shortStrike);
        assertEq(cash, 100 * base);

        // spot is lower than both, cash should be capped
        spot = 2000 * base;
        cash = tester.getCashValueDebitPutSpread(spot, longStrike, shortStrike);
        assertEq(cash, 200 * base);
    }

    function testPutSpreadCashValueUnderflow() public {
        // the function assume input to have longStrike > shortStrike
        // if this is not the case, the result will be wrong
        uint256 spot = 3000 * base;
        uint256 longStrike = 3200 * base;
        uint256 shortStrike = 3300 * base;
        uint256 cash = tester.getCashValueDebitPutSpread(spot, longStrike, shortStrike);
        // underflow
        assertEq(cash, type(uint256).max - (100 * base) + 1);
    }
}
