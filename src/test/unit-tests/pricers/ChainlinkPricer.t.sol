// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import "forge-std/Test.sol";

import {ChainlinkPricer} from "src/core/pricers/ChainlinkPricer.sol";

import {MockERC20} from "src/test/mocks/MockERC20.sol";
import {MockOracle} from "src/test/mocks/MockOracle.sol";
import {MockChainlinkAggregator} from "src/test/mocks/MockChainlinkAggregator.sol";

import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

import "forge-std/console2.sol";

/**
 * @dev test internal function _toPriceWithUnitDecimals
 */
contract ChainlinkPricerInternalTests is ChainlinkPricer, Test {
    // solhint-disable-next-line no-empty-blocks
    constructor() ChainlinkPricer(address(0)) {}

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
        uint8 baseDecimals = uint8(18);
        uint8 quoteDecimals = uint8(8);
        uint256 base = 3000 * (10**baseDecimals);
        uint256 quote = 1 * (10**quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimals2() public {
        uint8 baseDecimals = uint8(8);
        uint8 quoteDecimals = uint8(18);
        uint256 base = 3000 * (10**baseDecimals);
        uint256 quote = 1 * (10**quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }

    function testDecimalConversionDiffDecimalsFuzz(uint8 baseDecimals, uint8 quoteDecimals) public {
        vm.assume(baseDecimals < 20);
        vm.assume(quoteDecimals < 20);
        uint256 base = 3000 * (10**baseDecimals);
        uint256 quote = 1 * (10**quoteDecimals);
        uint256 price = _toPriceWithUnitDecimals(base, quote, baseDecimals, quoteDecimals);

        // should return base denominated in 1e6 (UNIT)
        assertEq(price, 3000 * UNIT);
    }
}

/**
 * @dev test the onlyOwner functions (setAggregator)
 */
contract ChainlinkPricerConfigurationTest is Test {
    ChainlinkPricer private pricer;

    address private weth;
    address private usdc;

    address private random;

    address private aggregator;

    function setUp() public {
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        address oracle = address(new MockOracle());
        pricer = new ChainlinkPricer(oracle);
        aggregator = address(new MockChainlinkAggregator(8));
    }

    function testOwnerCanSetAggregator() public {
        pricer.setAggregator(weth, aggregator, 3600, false);
        (uint160 addr, uint8 decimals, uint32 maxDelay, bool _isStable) = pricer.aggregators(weth);

        assertEq(address(addr), aggregator);
        assertEq(decimals, 8);
        assertEq(maxDelay, 3600);
        assertEq(_isStable, false);
    }

    function testCannotSetAggregatorFromNonOwner() public {
        vm.startPrank(random);

        vm.expectRevert("Ownable: caller is not the owner");
        pricer.setAggregator(weth, aggregator, 3600, false);

        vm.stopPrank();
    }

    function testCanResetAggregator() public {
        pricer.setAggregator(weth, aggregator, 360, false);
        pricer.setAggregator(weth, aggregator, 20000, false);
    }
}

/**
 * @dev test public functions
 */
contract ChainlinkPricerTest is Test {
    uint256 private aggregatorUint = 1e8;

    ChainlinkPricer private pricer;

    address private weth;
    address private usdc;

    address private random;

    MockChainlinkAggregator private wethAggregator;
    MockChainlinkAggregator private usdcAggregator;

    function setUp() public {
        vm.warp(1656680000);
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        address oracle = address(new MockOracle());
        pricer = new ChainlinkPricer(oracle);

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        pricer.setAggregator(weth, address(wethAggregator), 3600, false);
        pricer.setAggregator(usdc, address(usdcAggregator), 129600, true);

        wethAggregator.setMockState(0, int256(4000 * aggregatorUint), block.timestamp);
        usdcAggregator.setMockState(0, int256(1 * aggregatorUint), block.timestamp);
    }

    function testSpotPrice() public {
        uint256 spot = pricer.getSpotPrice(weth, usdc);
        assertEq(spot, 4000 * UNIT);
    }

    function testSpotPriceReverse() public {
        uint256 spot = pricer.getSpotPrice(usdc, weth);
        assertEq(spot, UNIT / 4000);
    }

    function testCannotGetSpotWhenAggregatorIsStale() public {
        wethAggregator.setMockState(0, int256(4000 * aggregatorUint), block.timestamp - 3601);
        
        vm.expectRevert(Chainlink_StaleAnswer.selector);
        pricer.getSpotPrice(usdc, weth);
    }
}

/**
 * @dev test reporting expiry price and interaction with Oracle
 */
contract ChainlinkPricerTestWriteOracle is Test {
    uint256 private aggregatorUint = 1e8;

    ChainlinkPricer private pricer;

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

        address oracle = address(new MockOracle());
        pricer = new ChainlinkPricer(oracle);

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        pricer.setAggregator(weth, address(wethAggregator), wethMaxDelay, false);
        pricer.setAggregator(usdc, address(usdcAggregator), usdcMaxDelay, true);

        // mock 2 answers aruond expiry
        wethAggregator.setMockRound(wethRoundIdToReport, 4000 * 1e8, expiry - 1);
        wethAggregator.setMockRound(wethRoundIdToReport + 1, 4003 * 1e8, expiry + 30);

        // mock 1 answer for usdc
        usdcAggregator.setMockRound(usdcRoundIdToReport, 1 * 1e8, expiry - 12960 + 50);
    }

    function testCanReportPrice() public {
        pricer.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfStablePriceIsStale() public {
        // the usdc price is older than 129600 seconds (1.5 days) before expiry
        usdcAggregator.setMockRound(usdcRoundIdToReport, 1 * 1e8, expiry - usdcMaxDelay - 10);

        vm.expectRevert(Chainlink_StaleAnswer.selector);
        pricer.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfUnderlyingPriceIsStale() public {
        // the weth price is older than max delay
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry - wethMaxDelay - 10);

        vm.expectRevert(Chainlink_StaleAnswer.selector);
        pricer.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfWrongIdIsSpecified() public {
        // let's assume roundId is too small
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry - 1200);
        // answer of roundId +1 is still smaller than expiry
        wethAggregator.setMockRound(wethRoundIdToReport + 1, 4005 * 1e8, expiry - 2);

        vm.expectRevert(Chainlink_RoundIdTooSmall.selector);
        pricer.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }

    function testCannotReportPriceIfRoundIDIsTooHigh() public {
        // let's assume roundId is too high: timestamp is higher than expiry
        wethAggregator.setMockRound(wethRoundIdToReport, 4001 * 1e8, expiry + 1);

        vm.expectRevert(stdError.arithmeticError);
        pricer.reportExpiryPrice(weth, usdc, expiry, wethRoundIdToReport, usdcRoundIdToReport);
    }
}
