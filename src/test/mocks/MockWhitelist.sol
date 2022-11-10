// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IWhitelist.sol";

contract MockWhitelist is IWhitelist {
    mapping(address => bool) public grappaAccessList;
    mapping(address => bool) public sactionedList;

    function sanctioned(address _subAccount) external view override returns (bool) {
        return sactionedList[_subAccount];
    }

    function grappaAccess(address _subAccount) external view override returns (bool) {
        return grappaAccessList[_subAccount] && !sactionedList[_subAccount];
    }

    function setGrappaAccess(address _subAccount, bool access) external {
        grappaAccessList[_subAccount] = access;
    }

    function setSanctioned(address _subAccount, bool access) external {
        sactionedList[_subAccount] = access;
    }
}
