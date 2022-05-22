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
    function addCollateral(Account memory account, bytes memory _data) internal {
        (address collateral, uint256 amount) = abi.decode(_data, (address, uint256));
        if (account.collateral != address(0) && account.collateral != _collateral) revert WrongCollateral();

        account.collateral = _collateral;
        account.collateralAmount += uint80(_amount);
        marginAccounts[_account] = account;
    }

    function removeCollateral(Account memory account, bytes memory _data) internal {}

    function mintOption(Account memory account, bytes memory _data) internal {}

    function burnOption(Account memory account, bytes memory _data) internal {}

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    function merge(Account memory account, bytes memory _data) internal {}

    ///@dev split an MarginAccount with spread into short + long
    function split(Account memory account, bytes memory _data) internal {}
}
