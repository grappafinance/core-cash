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

        // Deploy core components
        (Grappa grappa, ,address optionToken) = deployCore();

        // deploy and register Cross Margin Engine
        deployCrossMarginEngine(grappa, optionToken);

        // deploy and register Oracles
        deployOracles(grappa);

        // Todo: transfer ownership to Grappa multisig and Hashnote accordingly.
        vm.stopBroadcast();
    }

    /// @dev deploy core contracts: Upgradable Grappa, non-upgradable OptionToken with descriptor 
    function deployCore() public returns (
            Grappa grappa,
            address optionDesciptor,
            address optionToken
        )
    {
        uint256 nonce = vm.getNonce(msg.sender);
        console.log("nonce", nonce);
        console.log("Deployer", msg.sender);

        console.log("\n---- START ----");

        // =================== Deploy Grappa (Upgradable) =============== //
        address optionTokenAddr = predictAddress(msg.sender, nonce + 4);
        
        address implementation = address(new Grappa(optionTokenAddr)); // nonce
        console.log("grappa implementation\t\t", address(implementation));
        bytes memory data = abi.encode(Grappa.initialize.selector);
        grappa = Grappa(address(new ERC1967Proxy(implementation, data))); // nonce + 1

        console.log("grappa proxy \t\t\t", address(grappa));

        // =================== Deploy Option Desciptor (Upgradable) =============== //

        address descriptorImpl = address(new OptionTokenDescriptor()); // nonce + 2
        bytes memory descriptorInitData = abi.encode(OptionTokenDescriptor.initialize.selector);
        optionDesciptor = address(new ERC1967Proxy(descriptorImpl, descriptorInitData)); // nonce + 3
        console.log("optionToken descriptor\t", optionDesciptor);


        // =============== Deploy OptionToken ================= //

        optionToken = address(new OptionToken(address(grappa), optionDesciptor)); // nonce + 4
        console.log("optionToken\t\t\t", optionToken);

        // revert if deployed contract is different than what we set in Grappa
        assert(address(optionToken) == optionTokenAddr); 

        console.log("\n---- Core deployment ended ----\n");
    }

    function deployCrossMarginEngine(Grappa grappa, address optionToken)
        public
        returns (address crossMarginEngine)
    {
        
        // ============ Deploy Cross Margin Engine (Upgradable) ============== // 
        address engineImplementation = address(new CrossMarginEngine(address(grappa), optionToken));
        bytes memory engineData = abi.encode(CrossMarginEngine.initialize.selector);
        crossMarginEngine = address(new ERC1967Proxy(engineImplementation, engineData));

        console.log("CrossMargin Engine: \t\t", crossMarginEngine);

        // ============ Register Full Margin Engine ============== // 
        {
            uint engineId = grappa.registerEngine(crossMarginEngine);
            console.log("   -> Registered ID:", engineId);
        }
    }

    function deployOracles(Grappa grappa) public {
        // ============ Deploy Chainlink Oracles ============== // 
        address clOracle = address(new ChainlinkOracle());
        address clOracleDisputable = address(new ChainlinkOracleDisputable());

        // ============ Register Oracles ============== //
        {
            uint8 oracleId1 = Grappa(grappa).registerOracle(clOracle);
            console.log("Chainlink Oracle: \t\t", clOracle);
            console.log("   -> Registered ID:", oracleId1);
            uint8 oracleId2 = Grappa(grappa).registerOracle(clOracleDisputable);
            console.log("Chainlink Oracle Disputable: \t", clOracleDisputable);
            console.log("   -> Registered ID:", oracleId2);
        }
    }
}
