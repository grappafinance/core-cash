// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
// import {ERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

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
    ///@dev grappa serve as the registry
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
     * @dev mint option token to an address. Can only be called by corresponding margin engine
     * @param _recipient    where to mint token to
     * @param _tokenId      tokenId to mint
     * @param _amount       amount to mint
     */
    function mint(
        address _recipient,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkAccessAndTokenId(_tokenId);
        _mint(_recipient, _tokenId, _amount, "");
    }

    /**
     * @dev burn option token from an address. Can only be called by corresponding margin engine
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     **/
    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkAccess(_tokenId);
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn option token from an address. Can only be called by grappa, used for settlement
     * @param _from         account to burn from
     * @param _tokenId      tokenId to burn
     * @param _amount       amount to burn
     **/
    function burnGrappaOnly(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkIsGrappa();
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev burn batch of option token from an address. Can only be called by grappa
     * @param _from         account to burn from
     * @param _ids          tokenId to burn
     * @param _amounts      amount to burn
     **/
    function batchBurnGrappaOnly(
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

    function _checkAccess(uint256 _tokenId) internal view {
        (, uint32 productId, , , ) = TokenIdUtil.parseTokenId(_tokenId);
        (uint8 engineId, , , ) = ProductIdUtil.parseProductId(productId);
        if (msg.sender != grappa.engines(engineId)) revert OT_Not_Authorized_Engine();
    }

    /**
     * @dev check if msg.sender is eligible for burning or minting certain token
     */
    function _checkAccessAndTokenId(uint256 _tokenId) internal view {
        (TokenType optionType, uint32 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = TokenIdUtil
            .parseTokenId(_tokenId);
        (uint8 engineId, , , ) = ProductIdUtil.parseProductId(productId);
        if (msg.sender != grappa.engines(engineId)) revert OT_Not_Authorized_Engine();

        // check option type and strikes
        // check that vanilla options doesnt have a shortStrike argument
        if ((optionType == TokenType.CALL || optionType == TokenType.PUT) && (shortStrike != 0)) revert OT_BadStrikes();

        // check that you cannot mint a "credit spread" token
        if (optionType == TokenType.CALL_SPREAD && (shortStrike < longStrike)) revert OT_BadStrikes();
        if (optionType == TokenType.PUT_SPREAD && (shortStrike > longStrike)) revert OT_BadStrikes();

        // check expiry
        if (expiry <= block.timestamp) revert OT_InvalidExpiry();
    }
}
