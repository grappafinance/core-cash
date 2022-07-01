// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import "forge-std/Test.sol";

import {Oracle} from "src/core/Oracle.sol";

import {MockERC20} from "src/test/mocks/MockERC20.sol";
import {MockPricer} from "src/test/mocks/MockPricer.sol";

import {MockChainlinkAggregator} from "src/test/mocks/MockChainlinkAggregator.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

import "forge-std/console2.sol";

/**
 * @dev test oracle functions, mocking pricers
 */
contract OracleTest is Test {
    Oracle public oracle;

    MockPricer public primary;
    MockPricer public secondary;

    uint256 private primaryAnswer = 4000 * UNIT;
    uint256 private secondaryAnswer = 3990 * UNIT;

    address private weth;
    address private usdc;

    constructor() {
        vm.warp(1656680000);
        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        primary = new MockPricer();
        secondary = new MockPricer();

        oracle = new Oracle(address(primary), address(secondary));
        primary.setOracle(address(oracle));
        secondary.setOracle(address(oracle));

        primary.setPrice(primaryAnswer);
        secondary.setPrice(secondaryAnswer);
    }

    function testShouldGetSpot() public {
        uint256 price = oracle.getSpotPrice(weth, usdc);
        assertEq(price, primaryAnswer);
    }

    function testShouldGetSecondaryAnswerIfFirstPricerRevert() public {
        primary.setSpotRevert(true);
        uint256 price = oracle.getSpotPrice(weth, usdc);
        assertEq(price, secondaryAnswer);
    }

    function testCannotReportFromNonPricer() public {
        vm.expectRevert(OC_OnlyPricerCanWrite.selector);
        oracle.reportExpiryPrice(weth, usdc, block.timestamp, primaryAnswer);
    }

    function testReportFromPrimaryPricer() public {
        uint256 expiry = block.timestamp - 1 days;
        primary.mockSetExpiryPrice(weth, usdc, expiry, primaryAnswer);
        assertEq(oracle.getPriceAtExpiry(weth, usdc, expiry), primaryAnswer);
    }

    function testReportFromSecondaryPricer() public {
        uint256 expiry = block.timestamp - 1 days;
        secondary.mockSetExpiryPrice(weth, usdc, expiry, secondaryAnswer);
        assertEq(oracle.getPriceAtExpiry(weth, usdc, expiry), secondaryAnswer);
    }

    function testCannotSetFuturePrice() public {
        vm.expectRevert(OC_CannotReportForFuture.selector);
        primary.mockSetExpiryPrice(weth, usdc, block.timestamp + 1, primaryAnswer);
    }
}
