// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {IOracle} from "src/interfaces/IOracle.sol";

/**
 * @title Oracle
 * @author antoncoding
 * @dev return underlying / strike price, with 6 decimals
 */
contract Oracle is IOracle {
    /**
     * @dev     get spot price of underlying, denominated in strike asset.
     */
    function getSpotPrice(
        address, /*_underlying*/
        address /*_strike*/
    ) external pure override returns (uint256 price) {
        return 3000 * 1e6;
    }

    /**
     * @dev     get expiry price of underlying, denominated in strike asset.
                can revert if expiry is in the future, or the price is not reported by authorized party.
     */
    function getPriceAtExpiry(
        address, /*_underlying*/
        address, /*_strike*/
        uint256 /*_expiry*/
    ) external pure returns (uint256 price) {
        return 3000 * 1e6;
    }
}
