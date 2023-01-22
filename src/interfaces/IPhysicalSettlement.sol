// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Settlement, Balance} from "../config/types.sol";

interface IPhysicalSettlement {
    function handleExercise(uint256 _tokenid, uint256 _debtAmount, uint256 _payoutAmount) external;

    function receiveDebtValue(address _asset, address _recipient, uint256 _amount) external;

    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) external;

    function getSettlementWindow() external view returns (uint256 window);

    function setSettlementWindow(uint256 _window) external;

    /**
     * how the short should be settled
     */
    function getBatchSettlementForShorts(uint256[] calldata _tokenIds, uint256[] calldata _amounts)
        external
        view
        returns (Balance[] memory debts, Balance[] memory payouts);
}
