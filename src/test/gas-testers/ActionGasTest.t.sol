// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/test/mocks/MockERC20.sol";

/* solhint-disable max-states-count */
/* solhint-disable no-empty-blocks */

import "src/core/OptionToken.sol";

import "src/core/pricers/ChainlinkPricer.sol";
import "src/core/Oracle.sol";
import "./MarginAccountGasTester.sol";

// mock aggregator
import "src/test/mocks/MockChainlinkAggregator.sol";

import "src/test/utils/Utilities.sol";
import "src/config/enums.sol";
import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

import {ActionHelper} from "src/test/shared/ActionHelper.sol";

/**
 * @dev This file doesn't test any of the contract behavior
        Instead, it's only used to give us better insight of how each action is performing gas-wise
 */
contract TestActionGas is Test, Utilities, ActionHelper {
    MockERC20 public usdc;
    MockERC20 public weth;

    Oracle public oracle;
    ChainlinkPricer public primaryPricer;

    MockChainlinkAggregator public wethAggregator;
    MockChainlinkAggregator public usdcAggregator;

    OptionToken public option;
    MarginAccountGasTester public tester;

    uint32 public productId;
    uint32 public productIdEthCollat;

    address private accountWithCollateral = address(uint160(address(this)) + 1);
    address private accountWithCall = address(uint160(address(this)) + 2);
    address private accountWithSpread = address(uint160(address(this)) + 3);

    uint256 private callId;
    uint256 private higherCallId;
    uint256 private callSpreadId;

    uint64 private expiry;
    uint64 private mintAmount;

    uint8 private usdcId;
    uint8 private wethId;

    constructor() {
        vm.warp(0xffff);

        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        address pricerAddr = addressFrom(address(this), 6);
        oracle = new Oracle(pricerAddr, address(0)); // nonce: 3

        // predit address of margin account and use it here
        address marginAccountAddr = addressFrom(address(this), 5);
        option = new OptionToken(marginAccountAddr); // nonce: 4

        // deploy gas tester! (instead of real margin account)
        tester = new MarginAccountGasTester(address(option), address(oracle)); // nonce 5

        primaryPricer = new ChainlinkPricer(address(oracle)); // nonce 6

        wethAggregator = new MockChainlinkAggregator(8); // nonce 7
        usdcAggregator = new MockChainlinkAggregator(8); // nonce 8

        primaryPricer.setAggregator(address(usdc), address(usdcAggregator), 86400, true);
        primaryPricer.setAggregator(address(weth), address(wethAggregator), 3600, false);

        wethAggregator.setMockState(1011, 3000 * 1e8, block.timestamp);
        usdcAggregator.setMockState(101, 1 * 1e8, block.timestamp);

        // register products
        usdcId = tester.registerAsset(address(usdc));
        wethId = tester.registerAsset(address(weth));

        productId = tester.getProductId(address(weth), address(usdc), address(usdc));
        productIdEthCollat = tester.getProductId(address(weth), address(usdc), address(weth));

        tester.setProductMarginConfig(productId, 180 days, 1 days, 6400, 800, 10000);
        tester.setProductMarginConfig(productIdEthCollat, 180 days, 1 days, 6400, 800, 10000);
    }

    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(tester), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(tester), type(uint256).max);

        // common parameters
        expiry = uint64(block.timestamp + 3 days);
        mintAmount = uint64(1 * UNIT);

        uint64 callStrike = uint64(4000 * UNIT);
        callId = getTokenId(TokenType.CALL, productId, expiry, callStrike, 0);

        uint64 higherStrike = uint64(4200 * UNIT);
        higherCallId = getTokenId(TokenType.CALL, productId, expiry, higherStrike, 0);

        callSpreadId = getTokenId(TokenType.CALL_SPREAD, productId, expiry, callStrike, higherStrike);

        // prepare common accounts
        uint80 depositAmount = 1000 * 1e6;

        // prepare "account with collateral"
        bytes memory data = abi.encode(address(this), depositAmount, usdcId);
        tester.addCollateral(accountWithCollateral, data);

        // prepare "account with call"
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(callId, address(this), mintAmount);
        tester.execute(accountWithCall, actions);

        // prepare "account with call spread"
        ActionArgs[] memory actions2 = new ActionArgs[](2);
        actions2[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions2[1] = createMintAction(callSpreadId, address(this), mintAmount);
        tester.execute(accountWithSpread, actions2);
    }

    function testAddCollateralGas() public {
        uint80 depositAmount = 1000 * 1e6;

        bytes memory data = abi.encode(address(this), depositAmount, usdcId);
        tester.addCollateral(address(this), data);
    }

    function testRemoveAllCollateral() public {
        uint80 removeAmount = 1000 * 1e6;

        bytes memory data = abi.encode(removeAmount, address(this));
        tester.removeCollateral(accountWithCollateral, data);
    }

    function testRemoveHalfCollateral() public {
        uint80 removeAmount = 500 * 1e6;

        bytes memory data = abi.encode(removeAmount, address(this));
        tester.removeCollateral(accountWithCollateral, data);
    }

    function testMintCall() public {
        bytes memory data = abi.encode(callId, address(this), mintAmount);
        tester.mintOption(accountWithCollateral, data);
    }

    function testMintWithAccountAlreadyHaveCall() public {
        bytes memory data = abi.encode(callId, address(this), mintAmount);
        tester.mintOption(accountWithCall, data);
    }

    function testBurnCall() public {
        uint64 burnAmount = uint64(1 * UNIT);
        bytes memory data = abi.encode(callId, address(this), burnAmount);
        tester.burnOption(accountWithCall, data);
    }

    function testBurnHalf() public {
        uint64 burnAmount = uint64(1 * UNIT) / 2;
        bytes memory data = abi.encode(callId, address(this), burnAmount);
        tester.burnOption(accountWithCall, data);
    }

    function testMerge() public {
        // mint some long
        bytes memory mintData = abi.encode(higherCallId, address(this), mintAmount);
        tester.mintOption(accountWithCollateral, mintData);

        // merge
        bytes memory data = abi.encode(higherCallId, address(this));
        tester.merge(accountWithCall, data);
    }

    function testSplit() public {
        // split
        bytes memory data = abi.encode(TokenType.CALL_SPREAD, address(this));
        tester.split(accountWithSpread, data);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
