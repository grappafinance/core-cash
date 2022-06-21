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
import "src/config/types.sol";

/**
 * @title   Settlement
 * @dev     this module takes care of settling option tokens. 
            By inheriting AssetRegistry, this module can have easy access to all product / asset details 
 */
contract Settlement is AssetRegistry {
    using FixedPointMathLib for uint256;

    /// @dev oracle address
    IOracle public immutable oracle;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;

    constructor(address _optionToken, address _oracle) {
        oracle = IOracle(_oracle);
        optionToken = IOptionToken(_optionToken);
    }

    /**
     * @dev calculate the payout for an expired option token
     * @param _tokenId  token id of option token
     * @param _amount   amount to settle
     * @return collateral asset to settle in
     * @return payout amount paid
     **/
    function getOptionPayout(uint256 _tokenId, uint256 _amount) public view returns (address, uint256 payout) {
        (
            TokenType tokenType,
            uint32 productId,
            uint64 expiry,
            uint64 longStrike,
            uint256 shortStrike
        ) = OptionTokenUtils.parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert NotExpired();

        (address underlying, address strike, address collateral, uint8 collatDecimals) = parseProductId(productId);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
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

        // payout is denominated in strike asset (usually USD), with {UNIT_DECIMALS} decimals
        payout = cashValue.mulDivDown(_amount, UNIT);

        // the following logic convert payout amount if collateral is not strike:
        if (collateral == underlying) {
            // collateral is underlying. payout should be devided by underlying price
            payout = payout.mulDivDown(UNIT, expiryPrice);
        } else if (collateral != strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = oracle.getPriceAtExpiry(collateral, strike, expiry);
            payout = payout.mulDivDown(UNIT, collateralPrice);
        }

        return (collateral, _convertDecimals(payout, UNIT_DECIMALS, collatDecimals));
    }

    /**
     * @dev parse product id into composing asset addresses
     * @param _productId product id
     */
    function parseProductId(uint32 _productId)
        public
        view
        returns (
            address underlying,
            address strike,
            address collateral,
            uint8 collateralDecimals
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
        AssetDetail memory collateralDetail = assets[collateralId];
        return (
            address(assets[underlyingId].addr),
            address(assets[strikeId].addr),
            address(collateralDetail.addr),
            collateralDetail.decimals
        );
    }

    /**
     * @notice    get product id from underlying, strike and collateral address
     * @dev       function will still return even if some of the assets are not registered
     * @param underlying  underlying address
     * @param strike      strike address
     * @param collateral  collateral address
     */
    function getProductId(
        address underlying,
        address strike,
        address collateral
    ) public view returns (uint32 id) {
        id = (uint32(ids[underlying]) << 24) + (uint32(ids[strike]) << 16) + (uint32(ids[collateral]) << 8);
    }

    /**
     * @dev get spot price for a productId
     * @param _productId productId
     * @return spotPrice denominated in UNIT
     */
    function getSpot(uint32 _productId) public view returns (uint256) {
        (address underlying, address strike, , ) = parseProductId(_productId);
        return oracle.getSpotPrice(underlying, strike);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     */
    function settleOption(uint256 _tokenId, uint256 _amount) external {
        (address collateral, uint256 payout) = getOptionPayout(_tokenId, _amount);

        optionToken.burn(msg.sender, _tokenId, _amount);

        IERC20(collateral).transfer(msg.sender, payout);
    }

    /**
     * @notice convert decimals
     * @param  _amount      number to convert
     * @param _fromDecimals the decimals _amount is denominated in
     * @param _toDecimals   the destination decimals
     */
    function _convertDecimals(
        uint256 _amount,
        uint8 _fromDecimals,
        uint8 _toDecimals
    ) internal pure returns (uint256) {
        if (_fromDecimals == _toDecimals) return _amount;

        if (_fromDecimals > _toDecimals) {
            uint8 diff;
            unchecked {
                diff = _fromDecimals - _toDecimals;
            }
            return _amount / (10**diff);
        } else {
            uint8 diff;
            unchecked {
                diff = _toDecimals - _fromDecimals;
            }
            return _amount * (10**diff);
        }
    }
}
