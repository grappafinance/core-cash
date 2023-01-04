// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Settlement} from "../config/types.sol";

interface IPhysicalSettlement {
    function setSettlementWindow(uint256 _window) external;

    function settlePhysicalToken(Settlement calldata _settlement) external;

    function getPhysicalSettlementPerToken(uint256 _tokenId) external view returns (Settlement memory settlement);
}
