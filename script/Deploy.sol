// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "../src/core/OptionToken.sol";
import "../src/core/Grappa.sol";
import "../src/core/engines/advanced-margin/AdvancedMarginEngine.sol";
import "../src/core/engines/advanced-margin/VolOracle.sol";

// todo: add fallback pricer too
import "../src/core/oracles/Oracle.sol";
import "../src/core/oracles/pricers/ChainlinkPricer.sol";

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
            Oracle oracle,
            address optionToken,
            address advancedMarginEngine
        )
    {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);

        console.log("deploying with", msg.sender);
        console.log("---- START ----");

        address oracleAddr = predictAddress(msg.sender, nonce + 1);

        address chainlinkPricer = address(new ChainlinkPricer(oracleAddr)); // nonce + 0
        console.log("chainlinkPricer", address(chainlinkPricer));

        oracle = new Oracle(chainlinkPricer, address(0)); // nonce + 1
        console.log("oracle", address(oracle));
        console.log("primary pricer set: ", address(Oracle(oracle).primaryPricer()));

        // prepare bytecode for Grappa
        address optionTokenAddr = predictAddress(msg.sender, nonce + 3);
        console.log("optionToken address (prediction)", optionTokenAddr);

        grappa = new Grappa(optionTokenAddr, address(oracle)); // nonce + 2
        console.log("grappa", address(grappa));

        // deploy following contracts directly, just so the address is the same as predicted by `create` (optionTokenAddr)
        optionToken = address(new OptionToken(address(grappa))); // nonce: 3
        console.log("optionToken", optionToken);

        address volOracle = address(new VolOracle()); // nonce: 4

        advancedMarginEngine = address(
            new AdvancedMarginEngine(address(grappa), address(oracle), volOracle, address(optionToken))
        ); // nonce: 5
        console.log("advancedMarginEngine", advancedMarginEngine);

        // setup
        uint8 engineId1 = Grappa(grappa).registerEngine(advancedMarginEngine);
        console.log("advancedMargin engine registered, id:", engineId1);

        // todo: setup vol oracles
    }
}
