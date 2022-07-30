// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SimpleMarginEngine} from "../../core/engines/SimpleMarginEngine.sol";
import "../../config/types.sol";

/**
 * @title SimpleMarginEngineGasTester
 * @dev this contract is only used to expose internal functions to be availabel in gas reports.
 *      so we can better optimize each action functions
 */
// contract SimpleMarginEngineGasTester is SimpleMarginEngine {
//     // solhint-disable-next-line no-empty-blocks
//     constructor(address _optionToken, address _oracle) SimpleMarginEngine(_optionToken, _oracle) {}

//     function addCollateral(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _addCollateral(account, _data, _subAccount);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }

//     function removeCollateral(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _removeCollateral(account, _data);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }

//     function mintOption(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _mintOption(account, _data);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }

//     function burnOption(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _burnOption(account, _data, _subAccount);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }

//     function merge(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _merge(account, _data, _subAccount);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }

//     function split(address _subAccount, bytes calldata _data) external {
//         Account memory account = marginAccounts[_subAccount];

//         _split(account, _data);

//         _assertAccountHealth(account);
//         marginAccounts[_subAccount] = account;
//     }
// }
