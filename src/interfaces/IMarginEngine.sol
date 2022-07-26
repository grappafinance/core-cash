// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenType} from "../config/types.sol";

interface IMarginEngine {
    function isAccountHealthy(address _subAccount) external view returns (bool);

    function getMinCollateral(address _subAccount) external view returns (uint256);

    function addCollateral(
        address _subAccount,
        uint80 _amount,
        uint8 _collateralId
    ) external;

    function removeCollateral(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) external;

    function mintOption(
        address _subAccount,
        uint256 optionId,
        uint64 amount
    ) external;

    function burnOption(
        address _subAccount,
        uint256 optionId,
        uint64 amount
    ) external;

    function merge(address _subAccount, uint256 _optionId) external returns (uint64 burnAmount);

    function split(address _subAccount, TokenType tokenType) external returns (uint256 optionId, uint64 mintAmount);

    function liquidate(
        address _subAccount,
        uint256[] memory tokensToBurn,
        uint256[] memory amountsToBurn
    ) external returns (uint8[] memory collateralIds, uint80[] memory amountsToPay);

    function settleAtExpiry(address _subAccount) external;

    function getPayout(uint256 tokenId, uint64 amount) external view returns (address collateral, uint256 payout);
}
