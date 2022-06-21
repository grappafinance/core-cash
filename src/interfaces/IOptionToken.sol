// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

interface IOptionToken {
    function mint(
        address _recipient,
        uint256 _tokenId,
        uint256 _amount
    ) external;

    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external;
}
