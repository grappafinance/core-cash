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
 * @notice util contract to setup testing environment
 * @dev this contract setup the Grappa proxy, CashOptionToken, and deploy mocked engine and mocked oracles
 */
contract Setup is Test, Utilities {
    Grappa public implementation;
    Grappa public grappa;
    MockERC20 internal weth;
    MockERC20 internal usdc;

    CashOptionToken internal option;

    MockOracle internal oracle;
    MockEngine internal engine;

    uint8 internal wethId;
    uint8 internal usdcId;

    uint8 internal engineId;

    uint8 internal oracleId;

    uint40 internal wethCollatProductId;
    uint40 internal usdcCollatProductId;

    uint64 internal expiry;

    function _setupGrappaTestEnvironment() internal {
        weth = new MockERC20("WETH", "WETH", 18); // nonce: 1
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 2

        address proxyAddr = predictAddress(address(this), 5);

        option = new CashOptionToken(proxyAddr, address(0)); // nonce: 3

        implementation = new Grappa(address(option)); // nonce: 4

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
