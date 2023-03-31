// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IWhitelist.sol";

contract MockWhitelist is IWhitelist {
    mapping(address => bool) public engineAccessList;
    mapping(address => bool) public sactionedList;

    function sanctioned(address _subAccount) external view override returns (bool) {
        return sactionedList[_subAccount];
    }

    function isAllowed(address _subAccount) external view override returns (bool) {
        return engineAccessList[_subAccount] && !sactionedList[_subAccount];
    }

    function setEngineAccess(address _subAccount, bool access) external {
        engineAccessList[_subAccount] = access;
    }

    function setSanctioned(address _subAccount, bool access) external {
        sactionedList[_subAccount] = access;
    }

    // add a function prefixed with test here so forge coverage will ignore this file
    function test() public {}
}
