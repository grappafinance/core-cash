// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/core/OptionToken.sol";
import "../src/core/OptionTokenDescriptor.sol";
import "../src/core/Grappa.sol";
import "../src/core/engines/cross-margin/CrossMarginEngine.sol";

import "../src/core/oracles/ChainlinkOracle.sol";
import "../src/core/oracles/ChainlinkOracleDisputable.sol";

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
            address optionDesciptor,
            address optionToken,
            address crossMarginEngine
        )
    {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);

        console.log("deploying with", msg.sender);
        console.log("---- START ----");

        // =================== Deploy Grappa (Upgradable) =============== //
        address optionTokenAddr = predictAddress(msg.sender, nonce + 5);
        console.log("optionToken address (prediction)", optionTokenAddr);

        address implementation = address(new Grappa(optionTokenAddr)); // nonce + 1
        console.log("grappa implementation", address(implementation));

        bytes memory data = abi.encode(Grappa.initialize.selector);
        grappa = Grappa(address(new ERC1967Proxy(implementation, data))); // nonce + 2

        console.log("grappa proxy", address(grappa));

        // =================== Deploy Option Desciptor (Upgradable) =============== //

        address descriptorImpl = address(new OptionTokenDescriptor()); // nonce + 3
        bytes memory descriptorInitData = abi.encode(OptionTokenDescriptor.initialize.selector);
        optionDesciptor = address(new ERC1967Proxy(descriptorImpl, descriptorInitData)); // nonce + 4
        console.log("optionToken descriptor", optionDesciptor);


        // =============== Deploy OptionToken ================= //

        optionToken = address(new OptionToken(address(grappa), optionDesciptor)); // nonce + 5
        console.log("optionToken", optionToken);

        assert(address(optionToken) == optionTokenAddr);

        // ============ Deploy Cross Margin Engine (Upgradable) ============== // 
        address engineImplementation = address(new CrossMarginEngine(address(grappa), optionTokenAddr)); // nonce 7
        bytes memory engineData = abi.encode(CrossMarginEngine.initialize.selector);
        crossMarginEngine = address(new ERC1967Proxy(engineImplementation, engineData));
        

        // ============ Register Full Margin Engine ============== // 
        {
            uint engineId = grappa.registerEngine(crossMarginEngine);
            console.log("CrossMarginEngine registered, id:", engineId);
        }


        // ============ Deploy Chainlink Oracles ============== // 
        address clOracle = address(new ChainlinkOracle());
        address clOracleDisputable = address(new ChainlinkOracleDisputable());

        // ============ Register Oracles ============== // 

        {
            uint8 oracleId1 = Grappa(grappa).registerOracle(clOracle);
            console.log("chainlink oracle registered, id:", oracleId1);
            uint8 oracleId2 = Grappa(grappa).registerOracle(clOracleDisputable);
            console.log("chainlink disputable oracle registered, id:", oracleId2);
        }
    }
}
