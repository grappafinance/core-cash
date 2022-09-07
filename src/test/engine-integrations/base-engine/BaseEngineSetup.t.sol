// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../mocks/MockERC20.sol";
import "../../mocks/MockOracle.sol";
import "../../mocks/MockChainlinkAggregator.sol";
import "../../mocks/MockEngine.sol";

// import "../../../core/engines/.sol";
import "../../../core/engines/advanced-margin/VolOracle.sol";
import "../../../core/Grappa.sol";
import "../../../core/OptionToken.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";

import "../../utils/Utilities.sol";

import {ActionHelper} from "../../shared/ActionHelper.sol";

// solhint-disable max-states-count

abstract contract BaseEngineSetup is Test, ActionHelper, Utilities {
    MockEngine internal engine;
    Grappa internal grappa;
    OptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    // usdc collateralized call / put
    uint32 internal productId;

    // eth collateralized call / put
    uint32 internal productIdEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predit address of margin account and use it here
        address grappaAddr = predictAddress(address(this), 5);

        option = new OptionToken(grappaAddr); // nonce: 4

        grappa = new Grappa(address(option), address(oracle)); // nonce: 5

        engine = new MockEngine(address(grappa), address(option)); // nonce 6

        // register products
        usdcId = grappa.registerAsset(address(usdc));
        wethId = grappa.registerAsset(address(weth));

        engineId = grappa.registerEngine(address(engine));

        // engineId = grappa.registerEngine(address(engine));

        productId = grappa.getProductId(engineId, address(weth), address(usdc), address(usdc));
        productIdEthCollat = grappa.getProductId(engineId, address(weth), address(usdc), address(weth));
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
