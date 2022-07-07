// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/utils/Strings.sol";

import "src/core/OptionToken.sol";
import "src/core/SimpleMargin/MarginAccount.sol";

// todo: add fallback pricer too
import "src/core/Oracle.sol";
import "src/core/pricers/ChainlinkPricer.sol";

import "src/test/utils/Utilities.sol";

import { Create2Deployer } from "./utils.sol";

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
            address oracle,
            address optionToken,
            address marginAccount
        )
    {
        console.log("deploying with", msg.sender);
        // deploy deployer to use create2
        Create2Deployer deployer = new Create2Deployer(); // nonce 0

        // prepare bytecode for Oracle
        address chainlinkPricerAddr = addressFrom(msg.sender, 4);
        bytes memory oCreationCode = type(Oracle).creationCode;
        bytes memory oBytecode = abi.encodePacked(oCreationCode, abi.encode(chainlinkPricerAddr, address(0)));
        oracle = deployWithLeadingZeros(deployer, 0, oBytecode, 2); // nonce 1
        console.log("oracle", oracle);
        console.log("primary pricer: ", address(Oracle(oracle).primaryPricer()));

        // prepare bytecode for MarginAccount
        address optionTokenAddr = addressFrom(msg.sender, 3);
        console.log("optionTokenAddr", optionTokenAddr);
        // deploy MarginAccount
        bytes memory maCreationCode = type(MarginAccount).creationCode;
        bytes memory maBytecode = abi.encodePacked(maCreationCode, abi.encode(optionTokenAddr, oracle));
        marginAccount = deployWithLeadingZeros(deployer, 0, maBytecode, 2); // nonce 2
        console.log("marginAccount", marginAccount);

        // deploy optionToken directly, just so the address is the same as predicted by `create` (optionTokenAddr) 
        optionToken = address(new OptionToken(marginAccount)); // nonce: 3
        console.log("optionToken", optionToken);
        
        address chainlinkPricer = address(new ChainlinkPricer(oracle)); // nonce: 4
        console.log("chainlinkPricer", chainlinkPricer);
    }

    function deployWithLeadingZeros(
        Create2Deployer deployer, 
        uint256 value, 
        bytes memory creationCode,
        uint8 zerosBytes
    ) 
        internal 
        returns (address addr) 
    {
        // pass in codeHash so the js library doesn't have to do it in every iteration
        bytes32 codeHash = keccak256(creationCode);

        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "script/findSalt.js";
        
        inputs[2] = toString(address(deployer));
        inputs[3] = toString(codeHash);
        inputs[4] = Strings.toString(uint256(zerosBytes));

        bytes memory res = vm.ffi(inputs);
        bytes32 salt = abi.decode(res, (bytes32));

        console.log("deploying with salt:");
        emit log_bytes32(salt);

        addr = deployer.deploy(value, creationCode, salt);
    }

    function toString(address account) public pure returns(string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(bytes32 value) public pure returns(string memory) {
        return toString(abi.encodePacked(value));
    }

    function toString(bytes memory data) public pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
