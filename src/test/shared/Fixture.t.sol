// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/test/mocks/MockERC20.sol";
import "src/test/mocks/MockOracle.sol";

import "src/core/Grappa.sol";
import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountEnums.sol";

abstract contract Fixture is Test {
    Grappa internal grappa;

    MockERC20 internal usdc;

    MockOracle internal oracle;

    address internal alice;
    address internal charlie;
    address internal bob;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6);

        oracle = new MockOracle();

        grappa = new Grappa(address(oracle));

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
}
