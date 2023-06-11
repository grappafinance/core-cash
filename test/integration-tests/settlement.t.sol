// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Grappa} from "../../src/core/Grappa.sol";
import {GrappaProxy} from "../../src/core/GrappaProxy.sol";
import {CashOptionToken} from "../../src/core/CashOptionToken.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";
import {MockEngine} from "../mocks/MockEngine.sol";

import {Utilities} from "../utils/Utilities.sol";

import {ProductIdUtil} from "../../src/libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../src/libraries/TokenIdUtil.sol";

import "../../src/config/errors.sol";
import "../../src/config/enums.sol";
import "../../src/config/constants.sol";

/**
 * @dev test on proxy contract
 */
contract GrappaProxyTest is Test, Utilities {
    Grappa public implementation;
    Grappa public grappa;
    MockERC20 private weth;
    MockERC20 private usdc;

    CashOptionToken private option;

    MockOracle oracle;
    MockEngine private engine;

    uint8 wethId;
    uint8 usdcId;

    uint8 engineId;

    uint8 oracleId;

    uint40 wethCollatProductId;
    uint40 usdcCollatProductId;

    uint64 expiry;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18); // nonce: 1
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 2

        address proxyAddr = predictAddress(address(this), 5);

        option = new CashOptionToken(proxyAddr, address(0)); // nonce: 3

        implementation = new Grappa(address(0)); // nonce: 4

        bytes memory data = abi.encodeWithSelector(Grappa.initialize.selector, address(this));
        grappa = Grappa(address(new GrappaProxy(address(implementation), data))); // nonce: 5

        assertEq(proxyAddr, address(grappa));

        wethId = grappa.registerAsset(address(weth));
        usdcId = grappa.registerAsset(address(usdc));

        // use mocked engine and oracle

        engine = new MockEngine();
        engine.setOption(address(option));

        engineId = grappa.registerEngine(address(engine));

        oracle = new MockOracle();
        oracleId = grappa.registerOracle(address(oracle));

        wethCollatProductId = ProductIdUtil.getProductId(oracleId, engineId, wethId, usdcId, wethId);
        usdcCollatProductId = ProductIdUtil.getProductId(oracleId, engineId, wethId, usdcId, usdcId);

        expiry = uint64(block.timestamp + 14 days);

        // give mock engine lots of eth and usdc so it can pay out
        weth.mint(address(engine), 100e18);
        usdc.mint(address(engine), 100000e6);

        oracle.setSpotPrice(address(usdc), 1e6);
        oracle.setSpotPrice(address(weth), 2000e6);
    }

    function testPayoutUSDCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 2300e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 300e6);
    }

    function testPayoutETHCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, wethCollatProductId, 1e6);
        vm.warp(expiry);
        uint256 expiryPrice = 2300e6;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertApproxEqAbs(payout, 300e6 * 1e18 / expiryPrice, 0.0001e18);
    }

    function testPayoutUSDCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 1500e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 500e6);
    }

    function testPayoutETHCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, wethCollatProductId, 1e6);
        uint256 expiryPrice = 1600e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertEq(payout, 0.25e18); // 400 payout with 1600 each eth
    }

    function testPayoutUSDCCollatCallSpread() public {
        // arrange
        uint256 tokenId = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 2300e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 200e6);
    }

    function testPayoutETHCollatPUTSpread() public {
        // arrange
        uint256 tokenId = _mintPutSpread(2000e6, 1800e6, wethCollatProductId, 1e6);
        uint256 expiryPrice = 1600e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertEq(payout, 0.125e18); // payout 200 with 1600 each eth
    }

    function _mintCallOption(uint64 strike, uint40 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, strike, 0);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function _mintPutOption(uint64 strike, uint40 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.PUT, productId, expiry, strike, 0);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function _mintCallSpread(uint64 strike1, uint64 strike2, uint40 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL_SPREAD, productId, expiry, strike1, strike2);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function _mintPutSpread(uint64 strike1, uint64 strike2, uint40 productId, uint256 amount) internal returns (uint256) {
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.PUT_SPREAD, productId, expiry, strike1, strike2);
        engine.mintOptionToken(address(this), tokenId, amount);
        return tokenId;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
