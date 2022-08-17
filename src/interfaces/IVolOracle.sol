// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVolOracle {
    /**
     * @notice return implied vol for an asset
     * @dev could revert in certain scenarios
     * @param _asset asset to query
     */
    function getImpliedVol(address _asset) external view returns (uint256);
}
