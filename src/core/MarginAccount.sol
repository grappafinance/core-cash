// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {OptionToken} from "./OptionToken.sol";

import {IMarginAccount} from "../interfaces/IMarginAccount.sol";
import {IERC20} from "../interfaces/IERC20.sol";

import {OptionTokenUtils} from "../libraries/OptionTokenUtils.sol";
import {MarginAccountLib} from "../libraries/MarginAccountLib.sol";

import "src/types/MarginAccountTypes.sol";
import "src/constants/TokenEnums.sol";
import "src/constants/MarginAccountConstants.sol";

contract MarginAccount is IMarginAccount, OptionToken {
    using MarginAccountLib for MarginAccountDetail;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    mapping(address => Account) public marginAccounts;

    // mocked
    uint256 public spotPrice = 3000 * UNIT;

    constructor() {}

    function addCollateral(
        address _account,
        address _collateral,
        uint256 _amount
    ) external {
        Account memory account = marginAccounts[_account];
        if (
            account.collateral != address(0) &&
            account.collateral != _collateral
        ) revert WrongCollateral();

        account.collateral = _collateral;
        account.collateralAmount += uint80(_amount);
        marginAccounts[_account] = account;

        IERC20(_collateral).transferFrom(msg.sender, address(this), _amount);
    }

    function mint(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _assertCallerHasAccess(_account);
        Account memory account = marginAccounts[_account];
        (TokenType optionType, , , , ) = OptionTokenUtils.parseTokenId(
            _tokenId
        );
        if (
            optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD
        ) {
            if (account.shortCallId == 0) account.shortCallId = _tokenId;
            else if (account.shortCallId != _tokenId) {
                revert InvalidShortTokenToMint();
            }
            account.shortCallAmount += uint80(_amount);
        } else {
            if (account.shortPutId == 0) account.shortPutId = _tokenId;
            else if (account.shortPutId != _tokenId) {
                revert InvalidShortTokenToMint();
            }
            account.shortPutAmount += uint80(_amount);
        }

        _mint(msg.sender, _tokenId, _amount, "");

        _assertAccountHealth(account);
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
        if ((uint160(_account) | 0xFF) != (uint160(msg.sender) | 0xFF))
            revert NoAccess();
    }

    function _assertAccountHealth(Account memory account) internal view {
        MarginAccountDetail memory detail = _getAccountDetail(account);

        uint256 minCollateral = detail.getMinCollateral(spotPrice, SHOCK_RATIO);

        if (account.collateralAmount < minCollateral)
            revert AccountUnderwater();
    }

    /// @dev convert Account struct from storage to in-memory detail struct
    function _getAccountDetail(Account memory account)
        internal
        pure
        returns (MarginAccountDetail memory detail)
    {
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
            (, , , uint64 longStrike, uint64 shortStrike) = OptionTokenUtils
                .parseTokenId(account.shortCallId);
            detail.longCallStrike = longStrike;
            detail.shortCallStrike = shortStrike;
        }

        // if it contains a put
        if (account.shortPutId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = OptionTokenUtils
                .parseTokenId(account.shortPutId);
            detail.longPutStrike = longStrike;
            detail.shortPutStrike = shortStrike;
        }

        // parse common field
        // use the OR operator, so as long as one of shortPutId or shortCallId is non-zero, got reflected here
        uint256 commonId = account.shortPutId | account.shortCallId;

        (, uint32 productId, uint64 expiry, , ) = OptionTokenUtils.parseTokenId(
            commonId
        );
        detail.isStrikeCollateral = OptionTokenUtils.productIsStrikeCollateral(
            productId
        );
        detail.expiry = expiry;
    }
}
