// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ActionArgs} from "../config/types.sol";

interface IMarginEngine {
    // function getMinCollateral(address _subAccount) external view returns (uint256);

    function execute(address _subAccount, ActionArgs[] calldata actions) external;

    function payCashValue(address _asset, address _recipient, uint256 _amount) external;

    function receiveDebtValue(address _asset, address _sender, address _subAccount, uint256 _amount) external;

    function getDebtAndPayoutPerToken(uint256 _tokenId)
        external
        view
        returns (address issuer, uint256 debtPerToken, uint256 payoutPerToken);
}
