// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @notice  CrossMarginEngineProxy is ERC1967Proxy
 * @dev     explicitly declare a contract here to increase readability
 */
contract CrossMarginEngineProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) {}
}
