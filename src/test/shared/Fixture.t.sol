// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/test/mocks/MockERC20.sol";
import "src/test/mocks/MockOracle.sol";

import "src/core/L1/MarginAccount.sol";
import "src/core/OptionToken.sol";

import "src/config/enums.sol";
import "src/config/types.sol";

import "src/test/utils/Utilities.sol";

import {ActionHelper} from "src/test/shared/ActionHelper.sol";

abstract contract Fixture is Test, ActionHelper, Utilities {
    MarginAccount internal grappa;
    OptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    // usdc collateralized call / put
    uint32 internal productId;

    // eth collateralized call / put
    uint32 internal productIdEthCollat;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1

        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predit address of margin account and use it here
        address marginAccountAddr = addressFrom(address(this), 5);
        option = new OptionToken(address(oracle), marginAccountAddr); // nonce: 4

        grappa = new MarginAccount(address(option)); // nonce 5

        // register products
        option.registerAsset(address(usdc));
        option.registerAsset(address(weth));

        productId = option.getProductId(address(weth), address(usdc), address(usdc));
        productIdEthCollat = option.getProductId(address(weth), address(usdc), address(weth));

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
        usdc.approve(address(grappa), type(uint256).max);
        weth.approve(address(grappa), type(uint256).max);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(_productId, address(anon), lotOfCollateral);
        actions[1] = createMintAction(_tokenId, address(_recipient), _amount);
        grappa.execute(address(anon), actions);

        vm.stopPrank();
    }
}
