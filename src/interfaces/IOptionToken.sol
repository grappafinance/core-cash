// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

interface IOptionToken {
    function parseProductId(uint32 _productId)
        external
        view
        returns (
            address underlying,
            address strike,
            address collateral
        );

    function getOptionPayout(uint256 _tokenId, uint256 _amount) external returns (address collateral, uint256 payout);

    function getSpot(uint32 productId) external view returns (uint256);

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
