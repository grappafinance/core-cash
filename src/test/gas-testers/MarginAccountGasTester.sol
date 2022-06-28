// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MarginAccount} from "src/core/SimpleMargin/MarginAccount.sol";
import "src/config/types.sol";

/**
 * @title MarginAccountGasTester
 * @dev this contract is only used to expose internal functions to be availabel in gas reports.
 *      so we can better optimize each action functions
 */
contract MarginAccountGasTester is MarginAccount {
    constructor(address _optionToken, address _oracle) MarginAccount(_optionToken, _oracle) {}

    function addCollateral(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _addCollateral(account, _data, _accountId);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }

    function removeCollateral(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _removeCollateral(account, _data);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }

    function mintOption(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _mintOption(account, _data);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }

    function burnOption(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _burnOption(account, _data, _accountId);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }

    function merge(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _merge(account, _data, _accountId);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }

    function split(address _accountId, bytes calldata _data) external {
        Account memory account = marginAccounts[_accountId];

        _split(account, _data);

        _assertAccountHealth(account);
        marginAccounts[_accountId] = account;
    }
}
