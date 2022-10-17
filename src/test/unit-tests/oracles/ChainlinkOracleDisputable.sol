// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ChainlinkOracleDisputable} from "../../../core/oracles/ChainlinkOracleDisputable.sol";

import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockOracle} from "../../mocks/MockOracle.sol";
import {MockChainlinkAggregator} from "../../mocks/MockChainlinkAggregator.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @dev tests the disputable chainlink oracle
 */
contract ChainlinkOracleDisputableTest is Test {
    ChainlinkOracleDisputable private oracle;

    address private weth;
    address private usdc;

    address private random;

    address private aggregator;

    function setUp() public {
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        oracle = new ChainlinkOracleDisputable();
        aggregator = address(new MockChainlinkAggregator(8));
    }

    function testOwnerCanSetDisputePeriod() public {
        oracle.setDisputePeriod(weth, usdc, 3600);
        assertEq(oracle.disputePeriod(weth, usdc), 3600);
    }

    function testCannotSetDisputePeriodFromNonOwner() public {
        vm.startPrank(random);

        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setDisputePeriod(weth, usdc, 3600);

        vm.stopPrank();
    }

    function testCannotSetDisputePeriodThatIsTooHigh() public {
        vm.expectRevert(OC_InvalidDisputePeriod.selector);
        oracle.setDisputePeriod(weth, usdc, 12 hours + 1);
    }
}
