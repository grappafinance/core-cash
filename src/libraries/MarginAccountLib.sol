// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "src/constants/MarginAccountConstants.sol";
import "src/types/MarginAccountTypes.sol";
import "src/libraries/OptionTokenUtils.sol";

/**
 * @title MarginAccountLib
 * @dev   This library is in charge of updating the account memory and do validations
 */
library MarginAccountLib {
    function addCollateral(
        Account memory account,
        address collateral,
        uint256 amount
    ) internal pure {
        if (account.collateral != address(0) && account.collateral != collateral) revert WrongCollateral();

        account.collateral = collateral;
        account.collateralAmount += uint80(amount);
    }

    function removeCollateral(Account memory account, uint256 amount) internal pure {
        account.collateralAmount += uint80(amount);
        if (account.collateralAmount == 0) account.collateral = address(0);
    }

    function mintOption(
        Account memory account,
        uint256 tokenId,
        uint256 amount
    ) internal pure {
        TokenType optionType = OptionTokenUtils.parseTokenType(tokenId);
        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // minting a short
            if (account.shortCallId == 0) account.shortCallId = tokenId;
            else if (account.shortCallId != tokenId) revert InvalidShortTokenId();
            account.shortCallAmount += uint80(amount);
        } else {
            // minting a put or put spread
            if (account.shortPutId == 0) account.shortPutId = tokenId;
            else if (account.shortPutId != tokenId) revert InvalidShortTokenId();
            account.shortPutAmount += uint80(amount);
        }
    }

    function burnOption(
        Account memory account,
        uint256 tokenId,
        uint256 amount
    ) internal pure {
        TokenType optionType = OptionTokenUtils.parseTokenType(tokenId);
        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // burnning a call or call spread
            if (account.shortCallId != tokenId) revert InvalidShortTokenId();
            account.shortCallAmount -= uint80(amount);
            if (account.shortCallAmount == 0) account.shortCallId = 0;
        } else {
            // minting a put or put spread
            if (account.shortPutId != tokenId) revert InvalidShortTokenId();
            account.shortPutAmount -= uint80(amount);
            if (account.shortPutAmount == 0) account.shortPutId = 0;
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    function merge(Account memory account, bytes memory _data) internal {}

    ///@dev split an MarginAccount with spread into short + long
    function split(Account memory account, bytes memory _data) internal {}
}
