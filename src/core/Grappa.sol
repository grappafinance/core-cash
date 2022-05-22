// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {MarginAccount} from "./MarginAccount.sol";

contract Grappa is MarginAccount {
    uint256 public version = 1;

    constructor(address _oracle) MarginAccount(_oracle) {}
}
