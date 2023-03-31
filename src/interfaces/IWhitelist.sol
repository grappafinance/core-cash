// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IWhitelist {
    function sanctioned(address _subAccount) external view returns (bool);

    function isAllowed(address _subAccount) external view returns (bool);
}
