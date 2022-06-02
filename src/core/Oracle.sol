// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {IOracle} from "src/interfaces/IOracle.sol";

contract Oracle is IOracle {
    function getSpotPrice(
        address, /*_underlying*/
        address /*_strike*/
    ) external pure override returns (uint256 price) {
        return 3000 * 1e8;
    }

    function getPriceAtExpiry(
        address, /*_underlying*/
        address, /*_strike*/
        uint256 /*_expiry*/
    ) external pure returns (uint256 price) {
        return 3000 * 1e8;
    }
}
