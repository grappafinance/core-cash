// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ChainlinkOracle} from "../../../src/core/oracles/ChainlinkOracle.sol";

import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockOracle} from "../../mocks/MockOracle.sol";
import {MockChainlinkAggregator} from "../../mocks/MockChainlinkAggregator.sol";

import "../../../src/config/enums.sol";
import "../../../src/config/types.sol";
import "../../../src/config/constants.sol";
import "../../../src/core/oracles/errors.sol";

/**
 * @dev test internal function _toPriceWithUnitDecimals
 */
contract ChainlinkOracleInternalTests is ChainlinkOracle, Test {
    constructor() ChainlinkOracle(address(this)) {}

    function testDecimalConversion0Decimals() public {
        uint256 base = 1000;
        uint256 price = _toPriceWithUnitDecimals(base, 1, 0, 0);
        assertEq(price, base * UNIT);
    }

    function testDecimalConversionNormalDecimals() public {
        uint256 chainlinkUnit = 1e8;
        uint256 base = 3000 * chainlinkUnit;
        uint256 quote = 1 * chainlinkUnit;
        uint256 price = _toPriceWithUnitDecimals(base, quote, 8, 8);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimals() public {
        // baseMulDecimals = UNIT_DECIMALS + int8(_quoteDecimals) - int8(_baseDecimals) < 0
        uint8 baseDecimals = uint8(18);
        uint8 quoteDecimals = uint8(8);
        uint256 base = 3000 * (10 ** baseDecimals);
        uint256 quote = 1 * (10 ** quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimals2() public {
        // baseMulDecimals = UNIT_DECIMALS + int8(_quoteDecimals) - int8(_baseDecimals) > 0
        uint8 baseDecimals = uint8(8);
        uint8 quoteDecimals = uint8(18);
        uint256 base = 3000 * (10 ** baseDecimals);
        uint256 quote = 1 * (10 ** quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimals3() public {
        // baseMulDecimals = UNIT_DECIMALS + int8(_quoteDecimals) - int8(_baseDecimals) == 0
        uint8 baseDecimals = uint8(6);
        uint8 quoteDecimals = uint8(12);
        uint256 base = 3000 * (10 ** baseDecimals);
        uint256 quote = 1 * (10 ** quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimalsFuzz(uint8 baseDecimals, uint8 quoteDecimals) public {
        vm.assume(baseDecimals < 20);
        vm.assume(quoteDecimals < 20);
        uint256 base = 3000 * (10 ** baseDecimals);
        uint256 quote = 1 * (10 ** quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }
}

/**
 * @dev test the onlyOwner functions (setAggregator)
 */
contract ChainlinkOracleConfigurationTest is Test {
    ChainlinkOracle private oracle;

    address private weth;
    address private usdc;

    address private random;

    address private aggregator;

    function setUp() public {
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        oracle = new ChainlinkOracle(address(this));
        aggregator = address(new MockChainlinkAggregator(8));
    }

    function testDisputePeriodIs0() public {
        uint256 period = oracle.maxDisputePeriod();
        assertEq(period, 0);
    }

    function testOwnerCanSetAggregator() public {
        oracle.setAggregator(weth, aggregator, 3600, false);
        (address addr, uint8 decimals, uint32 maxDelay, bool _isStable) = oracle.aggregators(weth);

        assertEq(addr, aggregator);
        assertEq(decimals, 8);
        assertEq(maxDelay, 3600);
        assertEq(_isStable, false);
    }

    function testCannotSetAggregatorFromNonOwner() public {
        vm.startPrank(random);

        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setAggregator(weth, aggregator, 3600, false);

        vm.stopPrank();
    }

    function testCanResetAggregator() public {
        oracle.setAggregator(weth, aggregator, 360, false);
        oracle.setAggregator(weth, aggregator, 20000, false);
    }
}

/**
 * @dev test public functions
 */
contract ChainlinkOracleTest is Test {
    uint256 private aggregatorUint = 1e8;

    ChainlinkOracle private oracle;

    address private weth;
    address private usdc;

    address private random;

    MockChainlinkAggregator private wethAggregator;
    MockChainlinkAggregator private usdcAggregator;

    // abnormal aggregators
    address private usd1 = address(0x11);
    address private usd2 = address(0x22);
    MockChainlinkAggregator private usdAggregatorHighDecimals;
    MockChainlinkAggregator private usdAggregatorLowDecimals;

    function setUp() public {
        vm.warp(1656680000);
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        oracle = new ChainlinkOracle(address(this));

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        // aggregator with diff decimals
        usdAggregatorHighDecimals = new MockChainlinkAggregator(24);
        usdAggregatorLowDecimals = new MockChainlinkAggregator(1);

        oracle.setAggregator(weth, address(wethAggregator), 3600, false);
        oracle.setAggregator(usdc, address(usdcAggregator), 129600, true);

        oracle.setAggregator(usd1, address(usdAggregatorHighDecimals), 129600, true);
        oracle.setAggregator(usd2, address(usdAggregatorLowDecimals), 129600, true);

        wethAggregator.setMockState(0, int256(4000 * aggregatorUint), block.timestamp);
        usdcAggregator.setMockState(0, int256(1 * aggregatorUint), block.timestamp);

        usdAggregatorHighDecimals.setMockState(0, int256(1 * 10 ** 24), block.timestamp);
        usdAggregatorLowDecimals.setMockState(0, int256(1 * 10), block.timestamp);
    }

    function testSpotPrice() public {
        uint256 spot = oracle.getSpotPrice(weth, usdc);
        assertEq(spot, 4000 * UNIT);
    }

    function testSpotPriceDiffDecimals1() public {
        uint256 spot = oracle.getSpotPrice(weth, usd1);
        assertEq(spot, 4000 * UNIT);
    }

    function testSpotPriceDiffDecimals2() public {
        uint256 spot = oracle.getSpotPrice(weth, usd2);
        assertEq(spot, 4000 * UNIT);
    }

    function testSpotPriceReverse() public {
        uint256 spot = oracle.getSpotPrice(usdc, weth);
        assertEq(spot, UNIT / 4000);
    }

    function testCannotGetSpotWhenAggregatorIsStale() public {
        wethAggregator.setMockState(0, int256(4000 * aggregatorUint), block.timestamp - 3601);

        vm.expectRevert(CL_StaleAnswer.selector);
        oracle.getSpotPrice(usdc, weth);
    }

    function testCannotGetSpotWhenAggregatorIsNotSet() public {
        vm.expectRevert(CL_AggregatorNotSet.selector);
        oracle.getSpotPrice(usdc, address(1234));
    }
}

/**
 * @dev test reporting expiry price and interaction with Oracle
 */
contract ChainlinkOracleTestWriteOracle is Test {
    uint256 private aggregatorUint = 1e8;

    ChainlinkOracle private oracle;

    address private weth;
    address private usdc;

    address private random;

    MockChainlinkAggregator private wethAggregator;
    MockChainlinkAggregator private usdcAggregator;

    uint80 private expiry;

    uint32 private constant wethMaxDelay = 3600;
    uint32 private constant usdcMaxDelay = 129600;

    uint80 private wethRoundIdToReport = 881032;
    uint80 private usdcRoundIdToReport = 125624;

    function setUp() public {
        // set an normal number
        vm.warp(1656680000);

        expiry = uint80(block.timestamp - 1200);

        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        oracle = new ChainlinkOracle(address(this));

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        oracle.setAggregator(weth, address(wethAggregator), wethMaxDelay, false);
        oracle.setAggregator(usdc, address(usdcAggregator), usdcMaxDelay, true);

        // mock 2 answers aruond expiry
        wethAggregator.setMockRound(wethRoundIdToReport, 4000 * 1e8, expiry - 1);
        wethAggregator.setMockRound(wethRoundIdToReport + 1, 4003 * 1e8, expiry + 30);

        // mock 1 answer for usdc
        usdcAggregator.setMockRound(usdcRoundIdToReport, 1 * 1e8, expiry - 12960 + 50);

        vm.warp(expiry + 30);
    }

    function testCanReportPrice() public {
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);

        (uint256 price,) = oracle.getPriceAtExpiry(weth, usdc, expiry);
        assertEq(price, 4000 * UNIT);
    }

    function testCannotReportPriceTwice() public {
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);

        vm.expectRevert(OC_PriceReported.selector);
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotGetUnreportedExpiry() public {
        vm.expectRevert(OC_PriceNotReported.selector);
        oracle.getPriceAtExpiry(weth, usdc, expiry);
    }

    function testCannotReportPriceInTheFuture() public {
        // assume for whatever reason, weth aggregator has data for the future
        wethAggregator.setMockRound(wethRoundIdToReport + 1, 4003 * 1e8, block.timestamp + 30);

        // the oracle should still revert if someone is trying to set the price for the future
        vm.expectRevert(OC_CannotReportForFuture.selector);
        oracle.reportExpiryPrice(weth, usdc, block.timestamp + 10, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportWhenAggregatorIsNotSet() public {
        vm.expectRevert(CL_AggregatorNotSet.selector);
        oracle.reportExpiryPrice(weth, address(1234), expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfStablePriceIsStale() public {
        // the usdc price is older than 129600 seconds (1.5 days) before expiry
        usdcAggregator.setMockRound(usdcRoundIdToReport, 1 * 1e8, expiry - usdcMaxDelay - 10);

        vm.expectRevert(CL_StaleAnswer.selector);
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfUnderlyingPriceIsStale() public {
        // the weth price is older than max delay
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry - wethMaxDelay - 10);

        vm.expectRevert(CL_StaleAnswer.selector);
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfWrongIdIsSpecified() public {
        // let's assume roundId is too small
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry - 1200);
        // answer of roundId +1 is still smaller than expiry
        wethAggregator.setMockRound(wethRoundIdToReport + 1, 4005 * 1e8, expiry - 2);

        vm.expectRevert(CL_RoundIdTooSmall.selector);
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfRoundIDIsTooHigh() public {
        // let's assume roundId is too high: timestamp is higher than expiry
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry + 1);

        vm.expectRevert(stdError.arithmeticError);
        oracle.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }
}
