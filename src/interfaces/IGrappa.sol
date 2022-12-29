// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../config/types.sol";

interface IGrappa {
    function getDetailFromProductId(uint40 _productId)
        external
        view
        returns (
            address oracle,
            address engine,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            uint8 strikeDecimals,
            address collateral,
            uint8 collateralDecimals
        );

    function checkEngineAccess(uint256 _tokenId, address _engine) external view;

    function checkEngineAccessAndTokenId(uint256 _tokenId, address _engine) external view;

    function engineIds(address _engine) external view returns (uint8 id);

    function assetIds(address _asset) external view returns (uint8 id);

    function assets(uint8 _id) external view returns (address addr, uint8 decimals);

    function engines(uint8 _id) external view returns (address engine);

    function oracles(uint8 _id) external view returns (address oracle);

    function getSettlement(uint256 _tokenId, uint64 _amount) external view returns (Settlement memory settlement);

    /**
     * @notice burn token and settle at expiry
     * @param _account who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return debt amount owed
     * @return payout amount paid out
     */
    function settle(address _account, uint256 _tokenId, uint256 _amount) external returns (uint256 debt, uint256 payout);

    /**
     * @notice burn array of tokens and settle at expiry
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts array of amounts to burn
     * @param _dryRun flag to simulate transaction
     */
    function batchSettle(address _account, uint256[] memory _tokenIds, uint256[] memory _amounts, bool _dryRun)
        external
        returns (Balance[] memory debts, Balance[] memory payouts);
}
