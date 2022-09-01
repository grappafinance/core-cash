// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks

pragma solidity ^0.8.13;

import {IMarginEngine} from "../../interfaces/IMarginEngine.sol";
import {BaseEngine} from "../../core/engines/BaseEngine.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import "../../config/enums.sol";

/**
 * Mocked implementation to test base engine tx flow
 */
contract MockEngine is BaseEngine {
    bool public isAboveWater;

    uint80 public mockPayout;

    constructor(address _grappa, address _option) BaseEngine(_grappa, _option) {}

    function setIsAboveWater(bool _isAboveWater) external {
        isAboveWater = _isAboveWater;
    }

    function setPayout(uint80 _payout) external {
        mockPayout = _payout;
    }

    function payCashValue(
        address _asset,
        address _recipient,
        uint256 _amount
    ) public override {
        // BaseEngine.payCashValue(_asset, _recipient, _amount);
    }

    /** ========================================================= **
     *               Override Sate changing functions             *
     ** ========================================================= **/

    function _addCollateralToAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {}

    function _removeCollateralFromAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {}

    function _increaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {}

    function _decreaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {}

    function _mergeLongIntoSpread(
        address _subAccount,
        uint256 shortTokenId,
        uint256 longTokenId,
        uint64 amount
    ) internal override {}

    function _splitSpreadInAccount(
        address _subAccount,
        uint256 spreadId,
        uint64 amount
    ) internal override {}

    function _addOptionToAccount(
        address, /**_subAccount**/
        uint256, /**tokenId**/
        uint64 /**amount**/
    ) internal pure override {}

    function _removeOptionfromAccount(
        address, /**_subAccount**/
        uint256, /**tokenId**/
        uint64 /**amount**/
    ) internal pure override {}

    function _settleAccount(address _subAccount, uint80 payout) internal override {}

    /** ========================================================= **
                    Override view functions for BaseEngine
     ** ========================================================= **/

    function _isAccountAboveWater(
        address /*_subAccount*/
    ) internal view override returns (bool isHealthy) {
        return isAboveWater;
    }

    function _getAccountPayout(
        address /*_subAccount*/
    ) internal view override returns (uint80) {
        return mockPayout;
    }

    function _verifyLongTokenIdToAdd(
        uint256 /**_tokenId**/
    ) internal pure override {}

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
