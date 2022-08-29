// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// interfaces
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IGrappa} from "../interfaces/IGrappa.sol";

import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";

// constants and types
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   OptionToken
 * @author  antoncoding
 * @dev     each OptionToken represent the right to redeem cash value at expiry.
            The value of each OptionType should always be positive.
 */
contract OptionToken is ERC1155, IOptionToken {
    ///@dev marginAccount module which is in charge of minting / burning.
    IGrappa public immutable grappa;

    constructor(address _grappa) {
        // solhint-disable-next-line reason-string
        if (_grappa == address(0)) revert();
        grappa = IGrappa(_grappa);
    }

    // @todo: update function
    function uri(
        uint256 /*id*/
    ) public pure override returns (string memory) {
        return "https://grappa.maybe";
    }

    /**
     * @dev mint option token to an address. Can only be called by marginAccount
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     */
    function mint(
        address _recipient,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkIsAuth(_tokenId);
        _mint(_recipient, _tokenId, _amount, "");
    }

    /**
     * @dev burn option token from an address. Can only be called by marginAccount
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     **/
    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkIsAuth(_tokenId);
        _burn(_from, _tokenId, _amount);
    }

    function burnGrappaOnly(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkIsGrappa();
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn batch of option token from an address. Can only be called by marginAccount
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     **/
    function batchBurn(
        address _from,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external {
        _checkIsGrappa();
        _batchBurn(_from, _ids, _amounts);
    }

    /**
     * @dev check if msg.sender is the marginAccount
     */
    function _checkIsGrappa() internal view {
        if (msg.sender != address(grappa)) revert NoAccess();
    }

    /**
     * @dev check if msg.sender is eligible for burning or minting certain token
     */
    function _checkIsAuth(uint256 _tokenId) internal view {
        (, uint32 productId, , , ) = TokenIdUtil.parseTokenId(_tokenId);
        (uint8 engineId, , , ) = ProductIdUtil.parseProductId(productId);
        if (msg.sender != grappa.engines(engineId)) revert GP_Not_Authorized_Engine();
    }
}
