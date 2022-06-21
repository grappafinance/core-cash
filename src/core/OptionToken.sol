// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// inheriting cotract
import {AssetRegistry} from "src/core/AssetRegistry.sol";

// libraries
import {OptionTokenUtils} from "src/libraries/OptionTokenUtils.sol";
import {L1MarginMathLib} from "src/core/L1/libraries/L1MarginMathLib.sol";

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
contract OptionToken is ERC1155, IOptionToken, AssetRegistry {
    using FixedPointMathLib for uint256;

    IOracle public immutable oracle;
    address public immutable marginAccount;

    constructor(address _oracle, address _marginAccount) {
        oracle = IOracle(_oracle);
        marginAccount = _marginAccount;
    }

    // @todo: update function
    function uri(
        uint256 /*id*/
    ) public pure override returns (string memory) {
        return "https://grappa.maybe";
    }

    ///@dev calculate the payout for an expired option token
    ///@param _tokenId token id of option token
    ///@param _amount amount to settle
    function getOptionPayout(uint256 _tokenId, uint256 _amount)
        external
        view
        returns (address collateral, uint256 payout)
    {
        (
            TokenType tokenType,
            uint32 productId,
            uint64 expiry,
            uint64 longStrike,
            uint256 shortStrike
        ) = OptionTokenUtils.parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert NotExpired();

        (address underlying, address strike, address _collateral) = parseProductId(productId);

        uint256 cashValue;

        uint256 expiryPrice = oracle.getPriceAtExpiry(underlying, strike, expiry);

        if (tokenType == TokenType.CALL) {
            cashValue = L1MarginMathLib.getCallCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = L1MarginMathLib.getCashValueCallDebitSpread(expiryPrice, longStrike, shortStrike);
        } else if (tokenType == TokenType.PUT) {
            cashValue = L1MarginMathLib.getPutCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = L1MarginMathLib.getCashValuePutDebitSpread(expiryPrice, longStrike, shortStrike);
        }

        payout = cashValue.mulDivUp(_amount, UNIT);

        // todo: change unit to underlying if needed
        // bool strikeIsCollateral = strike == collateral;
        return (_collateral, payout);
    }

    // todo: move to somewhere appropriate
    function parseProductId(uint32 _productId)
        public
        view
        returns (
            address underlying,
            address strike,
            address collateral
        )
    {
        (uint8 underlyingId, uint8 strikeId, uint8 collateralId) = (0, 0, 0);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            underlyingId := shr(24, _productId)
            strikeId := shr(16, _productId)
            collateralId := shr(8, _productId)
            // the last 8 bits are not used
        }
        return (address(assets[underlyingId].addr), address(assets[strikeId].addr), address(assets[collateralId].addr));
    }

    ///@notice  get product id from underlying, strike and collateral address
    ///         function will still return if some of the assets are not registered
    function getProductId(
        address underlying,
        address strike,
        address collateral
    ) external view returns (uint32 id) {
        id = (uint32(ids[underlying]) << 24) + (uint32(ids[strike]) << 16) + (uint32(ids[collateral]) << 8);
    }

    ///@dev get spot price for a productId
    ///@param _productId productId
    function getSpot(uint32 _productId) external view returns (uint256) {
        (address underlying, address strike, ) = parseProductId(_productId);
        return oracle.getSpotPrice(underlying, strike);
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
        if (msg.sender != marginAccount) revert NotAuthorized();
    }
}
