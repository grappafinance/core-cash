// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenType} from "../config/types.sol";
import {ActionArgs} from "../config/types.sol";

interface IMarginEngine {
    // function getMinCollateral(address _subAccount) external view returns (uint256);

    // function previewMinCollateral(address _subAccount, ActionArgs[] calldata actions) external view returns (uint256);

    function execute(address _subAccount, ActionArgs[] calldata actions) external;

    function payCashValue(
        address _asset,
        address _recipient,
        uint256 _amount
    ) external;
}
