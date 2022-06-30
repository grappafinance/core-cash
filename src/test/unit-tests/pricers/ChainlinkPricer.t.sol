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

contract ChainlinkPricerConfigurationTest is Test {
    address private accountId;

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
