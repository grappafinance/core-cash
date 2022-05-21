// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {IMarginAccount} from "../interfaces/IMarginAccount.sol";

contract MarginAccount is IMarginAccount {
    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    mapping(address => Account) public accounts;

    constructor() {}

    function mint(
        uint256 _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {}

    function burn(
        uint256 _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {}

    function settleAccount(uint256 _account) external {}

    /// @dev add a ERC1155 long token into the margin account to reduce required collateral
    function merge() external {}
}
