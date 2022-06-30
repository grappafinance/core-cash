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
        pricer.setAggregator(weth, aggregator, 3600);
        (uint160 addr, uint8 decimals, uint32 maxDelay) = pricer.aggregators(weth);

        assertEq(address(addr), aggregator);
        assertEq(decimals, 8);
        assertEq(maxDelay, 3600);
    }

    function testCannotSetAggregatorFromNonOwner() public {
        vm.startPrank(random);

        vm.expectRevert("Ownable: caller is not the owner");
        pricer.setAggregator(weth, aggregator, 3600);

        vm.stopPrank();
    }

    function testCannotResetAggregator() public {
        pricer.setAggregator(weth, aggregator, 3600);

        vm.expectRevert(Chainlink_AggregatorAlreadySet.selector);
        pricer.setAggregator(weth, address(0), 20000);
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
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        address oracle = address(new MockOracle());
        pricer = new ChainlinkPricer(oracle);

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        pricer.setAggregator(weth, address(wethAggregator), 3600);
        pricer.setAggregator(usdc, address(usdcAggregator), 86400);

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
}
