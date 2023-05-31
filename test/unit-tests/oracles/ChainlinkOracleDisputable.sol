// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {ChainlinkOracleDisputable} from "../../../src/core/oracles/ChainlinkOracleDisputable.sol";

import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockOracle} from "../../mocks/MockOracle.sol";
import {MockChainlinkAggregator} from "../../mocks/MockChainlinkAggregator.sol";

import "../../../src/config/enums.sol";
import "../../../src/config/types.sol";
import "../../../src/config/constants.sol";
import "../../../src/core/oracles/errors.sol";

/**
 * @dev tests the disputable chainlink oracle
 */
contract ChainlinkOracleDisputableTest is Test {
    ChainlinkOracleDisputable private oracle;

    address private weth;
    address private usdc;

    uint256 private expiry;

    address private random;

    uint80 private roundId = 1;

    MockChainlinkAggregator private wethAggregator;
    MockChainlinkAggregator private usdcAggregator;

    function setUp() public {
        random = address(0xaabbff);

        usdc = address(new MockERC20("USDC", "USDC", 6));
        weth = address(new MockERC20("WETH", "WETH", 18));

        oracle = new ChainlinkOracleDisputable(address(this));

        wethAggregator = new MockChainlinkAggregator(8);
        usdcAggregator = new MockChainlinkAggregator(8);

        expiry = block.timestamp;

        wethAggregator.setMockRound(roundId, 1500 * 1e8, expiry);
        wethAggregator.setMockRound(roundId + 1, 1550 * 1e8, expiry + 10);

        usdcAggregator.setMockRound(roundId, 1 * 1e8, expiry);

        oracle.setAggregator(weth, address(wethAggregator), 1200, false);
        oracle.setAggregator(usdc, address(usdcAggregator), 86400, true);
    }

    function testDisputePeriodIsMax() public {
        assertEq(oracle.maxDisputePeriod(), MAX_DISPUTE_PERIOD);
    }

    function testOwnerCanSetDisputePeriod() public {
        oracle.setDisputePeriod(weth, usdc, 3600);
        assertEq(oracle.disputePeriod(weth, usdc), 3600);
    }

    function testCannotSetDisputePeriodFromNonOwner() public {
        vm.prank(random);
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.setDisputePeriod(weth, usdc, 3600);
    }

    function testCannotSetDisputePeriodThatIsTooHigh() public {
        vm.expectRevert(OC_InvalidDisputePeriod.selector);
        oracle.setDisputePeriod(weth, usdc, 6 hours + 1);
    }

    function testCannotDisputeUnReportedPrice() public {
        vm.expectRevert(OC_PriceNotReported.selector);
        oracle.disputePrice(weth, usdc, expiry + 1, 3000 * UNIT);
    }

    function testIsFinalizedIsFalseForUnreportedExpiry() public {
        assertEq(oracle.isExpiryPriceFinalized(weth, usdc, expiry), false);
    }

    function testCannotDisputeAfterDisputePeriod() public {
        uint256 period = 2 hours;
        oracle.setDisputePeriod(weth, usdc, period);
        oracle.reportExpiryPrice(weth, usdc, expiry, roundId, roundId);

        vm.warp(expiry + period + 1);

        vm.expectRevert(OC_DisputePeriodOver.selector);
        oracle.disputePrice(weth, usdc, expiry, 3000 * UNIT);

        // price is finalized
        assertEq(oracle.isExpiryPriceFinalized(weth, usdc, expiry), true);
    }

    function testOwnerDisputePrice() public {
        oracle.setDisputePeriod(weth, usdc, 2 hours);
        oracle.reportExpiryPrice(weth, usdc, expiry, roundId, roundId);
        // dispute
        oracle.disputePrice(weth, usdc, expiry, 3000 * UNIT);

        (uint256 price, bool isFinalized) = oracle.getPriceAtExpiry(weth, usdc, expiry);

        assertEq(price, 3000 * UNIT);
        assertEq(isFinalized, true);
    }

    function testCannotDisputeSameExpiryTwice() public {
        oracle.setDisputePeriod(weth, usdc, 2 hours);

        oracle.reportExpiryPrice(weth, usdc, expiry, roundId, roundId);

        oracle.disputePrice(weth, usdc, expiry, 3000 * UNIT);
        vm.expectRevert(OC_PriceDisputed.selector);
        oracle.disputePrice(weth, usdc, expiry, 3000 * UNIT);
    }

    // setExpiryPriceBackup tests

    function testCannotForceSetPriceIfPriceIsReported() public {
        oracle.reportExpiryPrice(weth, usdc, expiry, roundId, roundId);
        // setExpiryPriceBackup
        vm.expectRevert(OC_PriceReported.selector);
        oracle.setExpiryPriceBackup(weth, usdc, expiry, 3500 * UNIT);
    }

    function testCannotForceSetPriceRightAfterExpiry() public {
        vm.warp(expiry + 2 hours); // only 12 hours after expiry

        vm.expectRevert(OC_GracePeriodNotOver.selector);
        oracle.setExpiryPriceBackup(weth, usdc, expiry, 4000 * UNIT);
    }

    function testCannotForceSetPriceTwice() public {
        vm.warp(expiry + 36 hours);
        oracle.setExpiryPriceBackup(weth, usdc, expiry, 3500 * UNIT);

        vm.expectRevert(OC_PriceReported.selector);
        oracle.setExpiryPriceBackup(weth, usdc, expiry, 4000 * UNIT);
    }

    function testCanforceSetPriceIfPriceAfterGracePeriod() public {
        vm.warp(expiry + 36 hours);
        // setExpiryPriceBackup
        oracle.setExpiryPriceBackup(weth, usdc, expiry, 3500 * UNIT);
        (uint256 price, bool isFinalized) = oracle.getPriceAtExpiry(weth, usdc, expiry);
        assertEq(price, 3500 * UNIT);
        assertEq(isFinalized, true);
    }
}
