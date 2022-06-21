// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// interfaces
import {IOptionToken} from "src/interfaces/IOptionToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

// constants / types
import "src/config/enums.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

/**
 * @title   OptionToken
 * @author  antoncoding
 * @dev     each OptionToken represent the right to redeem cash value at expiry.
            The value of each OptionType should always be positive.
 */
contract OptionToken is ERC1155, IOptionToken {
    // IOracle public immutable oracle;
    address public immutable marginAccount;

    constructor(address _marginAccount) {
        // oracle = IOracle(_oracle);
        marginAccount = _marginAccount;
    }

    // @todo: update function
    function uri(
        uint256 /*id*/
    ) public pure override returns (string memory) {
        return "https://grappa.maybe";
    }

    ///@dev mint option token to an address. Can only be called by authorized contracts
    ///@param _recipient where to mint token to
    ///@param _tokenId tokenId to mint
    ///@param _amount amount to mint
    function mint(
        address _recipient,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkCanMint();
        _mint(_recipient, _tokenId, _amount, "");
    }

    ///@dev burn option token from an address. Can only be called by authorized contracts
    ///@param _from who's account to burn from
    ///@param _tokenId tokenId to burn
    ///@param _amount amount to burn
    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        _checkCanMint();
        _burn(_from, _tokenId, _amount);
    }

    ///@dev check if a rule has minter previlidge
    function _checkCanMint() internal view {
        if (msg.sender != marginAccount) revert NoAccess();
    }
}
