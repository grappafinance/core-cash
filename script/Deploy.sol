// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import "forge-std/Script.sol";

import "src/core/OptionToken.sol";
import "src/core/L1/MarginAccount.sol";

// todo: change to real oracle
import "src/test/mocks/MockOracle.sol";

import "src/test/utils/Utilities.sol";

contract Deploy is Script, Utilities {
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
}