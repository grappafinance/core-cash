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
}
