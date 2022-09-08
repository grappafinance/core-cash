// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {MoneynessLib} from "../../libraries/MoneynessLib.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

/**
 * Basic tests
 */
contract MoneynessLibTest is Test {
    uint256 public constant base = UNIT;

    function testCallCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = MoneynessLib.getCallCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot < strike
        spot = 2800 * base;
        cash = MoneynessLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);

        // spot = strike
        spot = 2900 * base;
        cash = MoneynessLib.getCallCashValue(spot, strike);
        assertEq(cash, 0);
    }

    function testPutCashValue() public {
        uint256 spot = 3000 * base;
        uint256 strike = 2900 * base;
        uint256 cash = MoneynessLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);

        // spot < strike
        spot = 2800 * base;
        cash = MoneynessLib.getPutCashValue(spot, strike);
        assertEq(cash, 100 * base);

        // spot = strike
        spot = 2900 * base;
        cash = MoneynessLib.getPutCashValue(spot, strike);
        assertEq(cash, 0);
    }
}
