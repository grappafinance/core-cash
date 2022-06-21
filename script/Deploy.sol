// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";

import "src/core/OptionToken.sol";
import "src/core/L1/MarginAccount.sol";

// todo: change to real oracle
import "src/test/mocks/MockOracle.sol";
import "src/test/utils/Utilities.sol";

import { Create2Deployer } from "./utils.sol";

contract Deploy is Script, Utilities {
    function run() external {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }

    function deploy()
        public
        returns (
            address oracle,
            address optionToken,
            address marginAccount
        )
    {
        // deploy deployer to use create2
        Create2Deployer deployer = new Create2Deployer(); // nonce 0

        // deploy oracle with 4 leading zeros
        oracle = deployWithLeadingZeros(deployer, 0, type(MockOracle).creationCode, 2); // nonce 1
        console.log("oracle", oracle);

        // prepare bytecode for MarginAccount
        address optionTokenAddr = addressFrom(msg.sender, 3);
        // deploy MarginAccount
        bytes memory maCreationCode = type(MarginAccount).creationCode;
        bytes memory maBytecode = abi.encodePacked(maCreationCode, abi.encode(optionTokenAddr, oracle));
        marginAccount = deployWithLeadingZeros(deployer, 0, maBytecode, 2); // nonce 2
        console.log("marginAccount", marginAccount);

        // deploy optionToken directly, just so the address is the same as predicted by `create` (optionTokenAddr) 
        optionToken = address(new OptionToken(marginAccount));
    }   

    function deployWithLeadingZeros(Create2Deployer deployer, uint256 value, bytes memory creationCode, uint8 zerosBytes) 
        internal 
        returns (address addr) 
    {
        uint8 bits = zerosBytes * 8;
        uint160 bound = type(uint160).max;

        // solhint-disable-next-line
        assembly {
            bound := shr(bits, bound)
        }
        uint256 salt;
        bytes32 codeHash = keccak256(creationCode);

        while (true) {
            address prediction = Create2.computeAddress(bytes32(salt), codeHash , address(deployer));
            if (uint160(prediction) < bound) break;
            unchecked {
                salt++;
            }
        }
        addr = deployer.deploy(value, creationCode, bytes32(salt));
    }
}
