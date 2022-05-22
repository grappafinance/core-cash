// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {OptionToken} from "./OptionToken.sol";

import {IMarginAccount} from "../interfaces/IMarginAccount.sol";
import {IERC20} from "../interfaces/IERC20.sol";

import {OptionTokenUtils} from "src/libraries/OptionTokenUtils.sol";
import {MarginMathLib} from "src/libraries/MarginMathLib.sol";
import {MarginAccountLib} from "src/libraries/MarginAccountLib.sol";

import "src/types/MarginAccountTypes.sol";
import {TokenType} from "src/constants/TokenEnums.sol";
import "src/constants/MarginAccountConstants.sol";

contract MarginAccount is IMarginAccount, OptionToken {
    using MarginMathLib for MarginAccountDetail;

    using MarginAccountLib for Account;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    mapping(address => Account) public marginAccounts;

    // mocked
    uint256 public spotPrice = 3000 * UNIT;

    constructor() {}

    ///@dev need to be reentry-guarded
    function execute(address _account, ActionArgs[] calldata actions) external {
        _assertCallerHasAccess(_account);
        Account memory account = marginAccounts[_account];

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(account, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(account, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mint(account, actions[i].data);

            // increase i without checking overflow
            unchecked {
                i++;
            }
        }
        _assertAccountHealth(account);
        marginAccounts[_account] = account;
    }

    function _addCollateral(Account memory _account, bytes memory _data) internal {
        (address collateral, uint256 amount) = abi.decode(_data, (address, uint256));
        // update the account structure
        _account.addCollateral(collateral, amount);
        IERC20(collateral).transferFrom(msg.sender, address(this), amount);
    }

    function _removeCollateral(Account memory _account, bytes memory _data) internal {
        (uint256 amount, address recipient) = abi.decode(_data, (uint256, address));
        // update the account memory structure
        address collateral = _account.collateral;
        _account.removeCollateral(amount);
        IERC20(collateral).transfer(recipient, amount);
    }

    function _mint(Account memory _account, bytes memory _data) internal {
        (uint256 tokenId, address recipient, uint256 amount) = abi.decode(_data, (uint256, address, uint256));
        _account.mintOption(tokenId, amount);

        // mint the real option token
        _mint(recipient, tokenId, amount, "");
    }

    // function burn(
    //     address _account,
    //     uint256 _tokenId,
    //     uint256 _amount
    // ) external {}

    // function settleAccount(address _account) external {}

    /// @dev add a ERC1155 long token into the margin account to reduce required collateral
    // function merge() external {}

    function _assertCallerHasAccess(address _account) internal view {
        if ((uint160(_account) | 0xFF) != (uint160(msg.sender) | 0xFF)) revert NoAccess();
    }

    function _assertAccountHealth(Account memory account) internal view {
        MarginAccountDetail memory detail = _getAccountDetail(account);

        uint256 minCollateral = detail.getMinCollateral(spotPrice, 1000);

        if (account.collateralAmount < minCollateral) revert AccountUnderwater();
    }

    /// @dev convert Account struct from storage to in-memory detail struct
    function _getAccountDetail(Account memory account) internal pure returns (MarginAccountDetail memory detail) {
        detail = MarginAccountDetail({
            putAmount: account.shortPutAmount,
            callAmount: account.shortCallAmount,
            longPutStrike: 0,
            shortPutStrike: 0,
            longCallStrike: 0,
            shortCallStrike: 0,
            expiry: 0,
            collateralAmount: account.collateralAmount,
            isStrikeCollateral: false
        });

        // if it contains a call
        if (account.shortCallId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = OptionTokenUtils.parseTokenId(account.shortCallId);
            detail.longCallStrike = longStrike;
            detail.shortCallStrike = shortStrike;
        }

        // if it contains a put
        if (account.shortPutId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = OptionTokenUtils.parseTokenId(account.shortPutId);
            detail.longPutStrike = longStrike;
            detail.shortPutStrike = shortStrike;
        }

        // parse common field
        // use the OR operator, so as long as one of shortPutId or shortCallId is non-zero, got reflected here
        uint256 commonId = account.shortPutId | account.shortCallId;

        (, uint32 productId, uint64 expiry, , ) = OptionTokenUtils.parseTokenId(commonId);
        detail.isStrikeCollateral = OptionTokenUtils.productIsStrikeCollateral(productId);
        detail.expiry = expiry;
    }
}
