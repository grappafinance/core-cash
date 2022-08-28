// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../test/mocks/MockERC20.sol";
import "../../test/mocks/MockOracle.sol";
import "../../test/mocks/MockChainlinkAggregator.sol";

import "../../core/engines/full-margin/FullMarginEngine.sol";
import "../../core/Grappa.sol";
import "../../core/OptionToken.sol";

import "../../config/enums.sol";
import "../../config/types.sol";

import "../utils/Utilities.sol";

import {ActionHelper} from "../../test/shared/ActionHelper.sol";

// solhint-disable max-states-count

/**
 * helper contract for full margin integration test to inherit.
 */
abstract contract FullMarginFixture is Test, ActionHelper, Utilities {
    FullMarginEngine internal fmEngine;
    Grappa internal grappa;
    OptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint32 internal pidUsdcCollat;

    // eth collateralized call / put
    uint32 internal pidEthCollat;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal fmEngineId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predit address of margin account and use it here
        address grappaAddr = predictAddress(address(this), 5);

        option = new OptionToken(grappaAddr); // nonce: 4

        grappa = new Grappa(address(option), address(oracle)); // nonce: 5

        fmEngine = new FullMarginEngine(address(grappa)); // nonce 6

        // register products
        usdcId = grappa.registerAsset(address(usdc));
        wethId = grappa.registerAsset(address(weth));

        fmEngineId = grappa.registerEngine(address(fmEngine));

        pidUsdcCollat = grappa.getProductId(fmEngineId, address(weth), address(usdc), address(usdc));
        pidEthCollat = grappa.getProductId(fmEngineId, address(weth), address(usdc), address(weth));

        charlie = address(0xcccc);
        vm.label(charlie, "Charlie");

        bob = address(0xb00b);
        vm.label(bob, "Bob");

        alice = address(0xaaaa);
        vm.label(alice, "Alice");

        // make sure timestamp is not 0
        vm.warp(0xffff);

        usdc.mint(alice, 1000_000_000 * 1e6);
        usdc.mint(bob, 1000_000_000 * 1e6);
        usdc.mint(charlie, 1000_000_000 * 1e6);
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

    function mintOptionFor(
        address _recipient,
        uint256 _tokenId,
        uint32 _productId,
        uint256 _amount
    ) internal {
        address anon = address(0x42424242);

        vm.startPrank(anon);

        uint256 lotOfCollateral = 1_000 * 1e18;

        usdc.mint(anon, lotOfCollateral);
        weth.mint(anon, lotOfCollateral);
        usdc.approve(address(fmEngine), type(uint256).max);
        weth.approve(address(fmEngine), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](2);

        uint8 collateralId = uint8(_productId);

        actions[0] = createAddCollateralAction(collateralId, address(anon), lotOfCollateral);
        actions[1] = createMintAction(_tokenId, address(_recipient), _amount);
        grappa.execute(fmEngineId, address(anon), actions);

        vm.stopPrank();
    }
}
