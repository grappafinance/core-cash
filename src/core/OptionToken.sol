// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// inheriting cotract
import {AssetRegistry} from "src/core/AssetRegistry.sol";

// libraries
import {OptionTokenUtils} from "src/libraries/OptionTokenUtils.sol";
import {MarginMathLib} from "src/libraries/MarginMathLib.sol";

// interfaces
import {IOptionToken} from "src/interfaces/IOptionToken.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

// constants / types
import "src/constants/TokenEnums.sol";
import "src/constants/MarginAccountConstants.sol";

/**
 * @title   OptionToken
 * @author  antoncoding
 * @dev     each OptionToken represent the right to redeem cash value at expiry.
            The value of each OptionType should always be positive.
 */
contract OptionToken is ERC1155, IOptionToken, AssetRegistry {
    using FixedPointMathLib for uint256;

    IOracle public immutable oracle;

    constructor(address _oracle) {
        oracle = IOracle(_oracle);
    }

    // @todo: update function
    function uri(
        uint256 /*id*/
    ) public pure override returns (string memory) {
        return "https://grappa.maybe";
    }

    ///@dev settle option and get out cash value
    function settleOption(uint256 _tokenId, uint256 _amount) external {
        (
            TokenType tokenType,
            uint32 productId,
            uint64 expiry,
            uint64 longStrike,
            uint256 shortStrike
        ) = OptionTokenUtils.parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert NotExpired();

        (address underlying, address strike, address collateral) = parseProductId(productId);

        uint256 cashValue;

        uint256 expiryPrice = oracle.getPriceAtExpiry(underlying, strike, expiry);

        if (tokenType == TokenType.CALL) {
            cashValue = MarginMathLib.getCallCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = MarginMathLib.getCashValueCallDebitSpread(expiryPrice, longStrike, shortStrike);
        } else if (tokenType == TokenType.PUT) {
            cashValue = MarginMathLib.getPutCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = MarginMathLib.getCashValuePutDebitSpread(expiryPrice, longStrike, shortStrike);
        }

        uint256 payout = cashValue.mulDivUp(_amount, UNIT);

        // todo: change unit to underlying if needed
        // bool strikeIsCollateral = strike == collateral;

        _burn(msg.sender, _tokenId, _amount);

        IERC20(collateral).transfer(msg.sender, payout);
    }

    function _getSpot(uint32 productId) internal view returns (uint256) {
        (address underlying, address strike, ) = parseProductId(productId);
        return oracle.getSpotPrice(underlying, strike);
    }
}
