// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import "forge-std/Script.sol";

import "src/core/OptionToken.sol";
import "src/core/L1/MarginAccount.sol";

// todo: change to real oracle
import "src/test/mocks/MockOracle.sol";

contract Deploy is Script {
  function run () external {
    vm.startBroadcast();

    deploy();

    vm.stopBroadcast();
  }

  function deploy() public returns (MockOracle oracle, OptionToken token, MarginAccount marginAccount)  {
    oracle = new MockOracle();

    address marginAccountAddr= addressFrom(msg.sender, 2);
    token = new OptionToken(address(oracle), marginAccountAddr);
    marginAccount = new MarginAccount(address(token));
    

  }

  // solhint-disable max-line-length
  function addressFrom(address _origin, uint _nonce) public pure returns (address) {
      if(_nonce == 0x00)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80))))));
      if(_nonce <= 0x7f)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce))))));
      if(_nonce <= 0xff)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce))))));
      if(_nonce <= 0xffff)   return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce))))));
      if(_nonce <= 0xffffff) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce))))));
      return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce))))));
  }
}