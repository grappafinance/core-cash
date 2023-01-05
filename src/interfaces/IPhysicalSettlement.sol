// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Settlement} from "../config/types.sol";

interface IPhysicalSettlement {
    function receiveDebtValue(address _asset, address _recipient, uint256 _amount) external;

    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) external;

    function getSettlementWindow() external view returns (uint256 window);

    function setSettlementWindow(uint256 _window) external;
}
