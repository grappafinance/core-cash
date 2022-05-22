// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {ERC1155} from "solmate/tokens/ERC1155.sol";

import {IOptionToken} from "../interfaces/IOptionToken.sol";

import {OptionTokenUtils} from "src/libraries/OptionTokenUtils.sol";

/**
 * @title   OptionToken
 * @author  antoncoding
 * @dev     each OptionToken represent the right to redeem cash value at expiry.
            The value of each OptionType should always be positive.
 */
contract OptionToken is ERC1155, IOptionToken {
    // @todo: update function
    function uri(
        uint256 /*id*/
    ) public pure override returns (string memory) {
        return "https://grappa.maybe";
    }

    ///@dev settle option and get out cash value
    function settleOption(uint256 _tokenId, uint256 _amount) external {
        (, uint32 productId, uint64 expiry, , ) = OptionTokenUtils.parseTokenId(_tokenId);

        // (,address strike, address collateral) = parseProductId(productId);

        // todo: check cash value and payout
    }
}
