// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {VolOracle} from "../../../core/engines/advanced-margin/VolOracle.sol";

import {MockChainlinkAggregator} from "../../mocks/MockChainlinkAggregator.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

contract VolOracleTest is Test {
    event AggregatorUpdated(address _asset, address _aggregator);

    VolOracle public volOracle;

    address public weth;

    MockChainlinkAggregator public wethAggregator;

    function setUp() public {
        volOracle = new VolOracle();

        weth = address(new MockERC20("WETH", "WETH", 18));

        wethAggregator = new MockChainlinkAggregator(8);
    }

    function testSetAggregator() public {
        volOracle.setAssetAggregator(weth, address(wethAggregator));
        assertEq(volOracle.aggregators(weth), address(wethAggregator));
    }

    function testSetAggregatorEmitEvent() public {
        vm.expectEmit(false, false, false, false, address(volOracle));
        emit AggregatorUpdated(weth, address(wethAggregator));
        volOracle.setAssetAggregator(weth, address(wethAggregator));
    }

    function testCannotSetAggregatorFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        volOracle.setAssetAggregator(weth, address(wethAggregator));
    }

    function testCannotSetAggregatorTwice() public {
        volOracle.setAssetAggregator(weth, address(wethAggregator));
        vm.expectRevert(VO_AggregatorAlreadySet.selector);
        volOracle.setAssetAggregator(weth, address(wethAggregator));
    }

    function testCannotReadVolForUnSetAddress() public {
        vm.expectRevert(VO_AggregatorNotSet.selector);
        volOracle.getImpliedVol(address(0xaabb));
    }

    function testVolIsUpdated() public {
        uint256 newVol = 2 * UNIT;
        volOracle.setAssetAggregator(weth, address(wethAggregator));
        wethAggregator.setMockState(0, int256(newVol), block.timestamp);
        assertEq(volOracle.getImpliedVol(weth), newVol);
    }
}
