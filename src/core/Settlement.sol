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
     * @notice burn option token and get out cash value at expiry
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     */
    function settleOption(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        (address collateral, uint256 payout) = getOptionPayout(_tokenId, _amount);

        optionToken.burn(_account, _tokenId, _amount);

        IERC20(collateral).transfer(_account, payout);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     * @param _collateral collateral asset to settle in.
     */
    function batchSettleOptions(
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _collateral
    ) external {
        if (_tokenIds.length != _amounts.length) revert WrongArgumentLength();

        uint256 totalPayout;

        for (uint256 i; i < _tokenIds.length; ) {
            (address collateral, uint256 payout) = getOptionPayout(_tokenIds[i], _amounts[i]);

            if (collateral != _collateral) revert WrongSettlementCollateral();
            totalPayout += payout;

            unchecked {
                i++;
            }
        }

        optionToken.batchBurn(msg.sender, _tokenIds, _amounts);

        IERC20(_collateral).transfer(msg.sender, totalPayout);
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
