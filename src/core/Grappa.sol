// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// interfaces
import {IOracle} from "../interfaces/IOracle.sol";
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";

// inheriting contract
import {Registry} from "./Registry.sol";

// librarise
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";
import {NumberUtil} from "../libraries/NumberUtil.sol";
import {MoneynessLib} from "../libraries/MoneynessLib.sol";

// constants and types
import "../config/types.sol";
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   Grappa
 * @author  @antoncoding
 */
contract Grappa is ReentrancyGuard, Registry {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint32;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;
    // IMarginEngine public immutable engine;
    IOracle public immutable oracle;

    constructor(address _optionToken, address _oracle) {
        optionToken = IOptionToken(_optionToken);
        oracle = IOracle(_oracle);
    }

    /*///////////////////////////////////////////////////////////////
                                  Events
    //////////////////////////////////////////////////////////////*/

    event OptionSettled(address account, uint256 tokenId, uint256 amountSettled, uint256 payout);

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     */
    function settleOption(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        (address engine, address collateral, uint256 payout) = getPayout(_tokenId, uint64(_amount));

        emit OptionSettled(_account, _tokenId, _amount, payout);

        optionToken.burnGrappaOnly(_account, _tokenId, _amount);

        IMarginEngine(engine).payCashValue(collateral, _account, payout);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     
     */
    function batchSettleOptions(
        address _account,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external {
        if (_tokenIds.length != _amounts.length) revert GP_WrongArgumentLength();

        if (_tokenIds.length == 0) return;

        optionToken.batchBurn(_account, _tokenIds, _amounts);

        address lastCollateral;
        address lastEngine;

        uint256 lastTotalPayout;

        for (uint256 i; i < _tokenIds.length; ) {
            (address engine, address collateral, uint256 payout) = getPayout(_tokenIds[i], uint64(_amounts[i]));

            // if engine or collateral changes, payout and clear temporary parameters
            if (lastEngine == address(0)) {
                lastEngine = engine;
                lastCollateral = collateral;
            } else if (engine != lastEngine || lastCollateral != collateral) {
                IMarginEngine(lastEngine).payCashValue(lastCollateral, _account, lastTotalPayout);
                lastTotalPayout = 0;
                lastEngine = engine;
                lastCollateral = collateral;
            }

            lastTotalPayout += payout;

            emit OptionSettled(_account, _tokenIds[i], _amounts[i], payout);

            unchecked {
                i++;
            }
        }

        IMarginEngine(lastEngine).payCashValue(lastCollateral, _account, lastTotalPayout);
    }

    /**
     * @dev calculate the payout for one option token
     *
     * @param _tokenId  token id of option token
     * @param _amount   amount to settle
     *
     * @return engine engine to settle
     * @return collateral asset to settle in
     * @return payout amount paid
     **/
    function getPayout(uint256 _tokenId, uint64 _amount)
        public
        view
        returns (
            address engine,
            address collateral,
            uint256 payout
        )
    {
        uint256 payoutPerOption;
        (engine, collateral, payoutPerOption) = _getPayoutPerToken(_tokenId);
        payout = payoutPerOption.mulDivDown(_amount, UNIT);
    }

    /**
     * @dev calculate the payout for one option token
     *
     * @param _tokenId  token id of option token
     *
     * @return collateral asset to settle in
     * @return payoutPerOption amount paid
     **/
    function _getPayoutPerToken(uint256 _tokenId)
        internal
        view
        returns (
            address,
            address,
            uint256 payoutPerOption
        )
    {
        (TokenType tokenType, uint32 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = TokenIdUtil
            .parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert GP_NotExpired();

        (
            address engine,
            address underlying,
            address strike,
            address collateral,
            uint8 collateralDecimals
        ) = getDetailFromProductId(productId);

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = oracle.getPriceAtExpiry(underlying, strike, expiry);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;
        if (tokenType == TokenType.CALL) {
            cashValue = MoneynessLib.getCallCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitCallSpread(expiryPrice, longStrike, shortStrike);
        } else if (tokenType == TokenType.PUT) {
            cashValue = MoneynessLib.getPutCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitPutSpread(expiryPrice, longStrike, shortStrike);
        }

        // the following logic convert cash value (amount worth) if collateral is not strike:
        if (collateral == underlying) {
            // collateral is underlying. payout should be devided by underlying price
            cashValue = cashValue.mulDivDown(UNIT, expiryPrice);
        } else if (collateral != strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = oracle.getPriceAtExpiry(collateral, strike, expiry);
            cashValue = cashValue.mulDivDown(UNIT, collateralPrice);
        }
        payoutPerOption = cashValue.convertDecimals(UNIT_DECIMALS, collateralDecimals);

        return (engine, collateral, payoutPerOption);
    }

    /**
     * @dev revert if the calling engine can not mint the token.
     * @param _engine address of the engine
     * @param _tokenId tokenid
     */
    function _assertIsAuthorizedEngineForToken(address _engine, uint256 _tokenId) internal view {
        (, uint32 productId, , , ) = TokenIdUtil.parseTokenId(_tokenId);
        address engine = getEngineFromProductId(productId);
        if (_engine != engine) revert GP_Not_Authorized_Engine();
    }
}
