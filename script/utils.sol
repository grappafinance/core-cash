// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Script.sol";

import "openzeppelin/utils/Create2.sol";

contract Create2Deployer {
    function deploy(uint256 value, bytes memory bytecode, bytes32 salt)
        external
        returns (address addr)
    {
        // solhint-disable-next-line
        assembly {
            addr := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }
    }
}