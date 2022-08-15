// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.13;

import {IMarginEngine} from "../../interfaces/IMarginEngine.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../../config/enums.sol";

contract MockEngine is IMarginEngine {
    bool public isSafe;
    uint256 public minCollateral;
    using SafeERC20 for IERC20;

    function isAccountHealthy(
        address /*_subAccount*/
    ) external view returns (bool) {
        return isSafe;
    }

    function setIsAccountSafe(bool _safe) external {
        isSafe = _safe;
    }

    function getMinCollateral(
        address /*_subAccount*/
    ) external view returns (uint256) {
        return minCollateral;
    }

    function increaseCollateral(
        address, /*_subAccount*/
        address _from,
        address _collateral,
        uint8, /*_collateralId*/
        uint80 _amount
    ) external {
        IERC20(_collateral).safeTransferFrom(_from, address(this), _amount);
    }

    function decreaseCollateral(
        address, /*_subAccount*/
        address _to,
        address _collateral,
        uint8, /* _collateralId*/
        uint80 _amount
    ) external {
        IERC20(_collateral).safeTransfer(_to, _amount);
    }

    function increaseDebt(
        address _subAccount,
        uint256 optionId,
        uint64 amount
    ) external {
        // do nothing
    }

    function decreaseDebt(
        address _subAccount,
        uint256 optionId,
        uint64 amount
    ) external {
        // do nothing
    }

    function merge(address _subAccount, uint256 _optionId) external returns (uint64 burnAmount) {
        // do nothing
    }

    function split(address _subAccount, uint256 _spreadId) external returns (uint256 optionId, uint64 mintAmount) {
        // do nothing
    }

    function liquidate(
        address _subAccount,
        address _liquidator,
        uint256[] memory tokensToBurn,
        uint256[] memory amountsToBurn
    ) external returns (address collateral, uint80 amountToPay) {
        // do nothing
    }

    function payCashValue(
        address _asset,
        address _recipient,
        uint256 _amount
    ) external {
        IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    function settleAtExpiry(address _subAccount) external {
        // do nothing
    }
}
