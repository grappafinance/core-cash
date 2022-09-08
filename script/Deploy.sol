// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "../src/core/OptionToken.sol";
import "../src/core/Grappa.sol";
import "../src/core/engines/advanced-margin/AdvancedMarginEngine.sol";
import "../src/core/engines/advanced-margin/VolOracle.sol";

import "../src/core/oracles/ChainlinkOracle.sol";

import "../src/test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }

    /// @dev the script currently only work with new deployer account (nonce = 0)
    function deploy()
        public
        returns (
            Grappa grappa,
            address optionToken,
            address advancedMarginEngine
        )
    {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);

        console.log("deploying with", msg.sender);
        console.log("---- START ----");

        // prepare bytecode for Grappa
        address optionTokenAddr = predictAddress(msg.sender, nonce + 2);
        console.log("optionToken address (prediction)", optionTokenAddr);

        grappa = new Grappa(optionTokenAddr); // nonce + 1
        console.log("grappa", address(grappa));

        // deploy following contracts directly, just so the address is the same as predicted by `create` (optionTokenAddr)
        optionToken = address(new OptionToken(address(grappa))); // nonce: 2
        console.log("optionToken", optionToken);

        address volOracle = address(new VolOracle()); // nonce: 3

        advancedMarginEngine = address(
            new AdvancedMarginEngine(address(grappa), volOracle, address(optionToken))
        ); // nonce: 5
        console.log("advancedMarginEngine", advancedMarginEngine);

        // setup
        uint8 engineId1 = Grappa(grappa).registerEngine(advancedMarginEngine);
        console.log("advancedMargin engine registered, id:", engineId1);

        // setup oracle
        address oracle = address(new ChainlinkOracle()); 

        uint8 oracleId1 = Grappa(grappa).registerOracle(oracle);
        console.log("chainlink oracle registered, id:", oracleId1);
    }
}
