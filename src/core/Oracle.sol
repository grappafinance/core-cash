// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

contract Oracle {
    uint256 public price = 3000e8;

    ///@dev get the asset price in USD term, sacled in 1e8
    function getPrice(
        address /*_asset*/
    ) external view returns (uint256) {
        return price;
    }
}
