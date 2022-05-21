// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

contract Oracle {
    uint256 public price = 3000e18;

    ///@dev get the asset price in USD term, sacled in 1e18
    function getPrice(
        address /*_asset*/
    ) external view returns (uint256) {
        return price;
    }
}
