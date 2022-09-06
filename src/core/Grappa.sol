// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

// interfaces
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";

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
contract Grappa is Ownable {
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint40;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;
    // IMarginEngine public immutable engine;
    IOracle public immutable oracle;

    /*///////////////////////////////////////////////////////////////
                            State Variables
    //////////////////////////////////////////////////////////////*/

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint8 public nextAssetId;

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint8 public nextengineId;

    /// @dev assetId => asset address
    mapping(uint8 => AssetDetail) public assets;

    /// @dev assetId => margin engine address
    mapping(uint8 => address) public engines;

    /// @dev address => assetId
    mapping(address => uint8) public assetIds;

    /// @dev address => engineId
    mapping(address => uint8) public engineIds;

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event OptionSettled(address account, uint256 tokenId, uint256 amountSettled, uint256 payout);
    event AssetRegistered(address asset, uint8 id);
    event MarginEngineRegistered(address engine, uint8 id);

    constructor(address _optionToken, address _oracle) {
        optionToken = IOptionToken(_optionToken);
        oracle = IOracle(_oracle);
    }

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev parse product id into composing asset and engine addresses
     * @param _productId product id
     */
    function getDetailFromProductId(uint40 _productId)
        public
        view
        returns (
            address engine,
            address underlying,
            address strike,
            address collateral,
            uint8 collateralDecimals
        )
    {
        (, uint8 engineId, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(
            _productId
        );
        AssetDetail memory collateralDetail = assets[collateralId];
        return (
            engines[engineId],
            assets[underlyingId].addr,
            assets[strikeId].addr,
            collateralDetail.addr,
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
        uint8 engineId,
        address underlying,
        address strike,
        address collateral
    ) external view returns (uint40 id) {
        id = ProductIdUtil.getProductId(0, engineId, assetIds[underlying], assetIds[strike], assetIds[collateral]);
    }

    /**
     * @notice    get token id from type, productId, expiry, strike
     * @dev       function will still return even if some of the assets are not registered
     * @param tokenType TokenType enum
     * @param productId if of the product
     * @param expiry timestamp of option expiry
     * @param longStrike strike price of the long option, with 6 decimals
     * @param shortStrike strike price of the short (upper bond for call and lower bond for put) if this is a spread. 6 decimals
     */
    function getTokenId(
        TokenType tokenType,
        uint32 productId,
        uint256 expiry,
        uint256 longStrike,
        uint256 shortStrike
    ) external pure returns (uint256 id) {
        id = TokenIdUtil.formatTokenId(tokenType, productId, uint64(expiry), uint64(longStrike), uint64(shortStrike));
    }

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

        optionToken.batchBurnGrappaOnly(_account, _tokenIds, _amounts);

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
            emit OptionSettled(_account, _tokenIds[i], _amounts[i], payout);

            unchecked {
                lastTotalPayout = lastTotalPayout + payout;
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
        payout = payoutPerOption * _amount;
        unchecked {
            payout = payout / UNIT;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev register an asset to be used as strike/underlying
     * @param _asset address to add
     **/
    function registerAsset(address _asset) external onlyOwner returns (uint8 id) {
        if (assetIds[_asset] != 0) revert GP_AssetAlreadyRegistered();

        uint8 decimals = IERC20Metadata(_asset).decimals();

        id = ++nextAssetId;
        assets[id] = AssetDetail({addr: _asset, decimals: decimals});
        assetIds[_asset] = id;

        emit AssetRegistered(_asset, id);
    }

    /**
     * @dev register an engine to create / settle options
     * @param _engine address of the new margin engine
     **/
    function registerEngine(address _engine) external onlyOwner returns (uint8 id) {
        if (engineIds[_engine] != 0) revert GP_EngineAlreadyRegistered();

        id = ++nextengineId;
        engines[id] = _engine;

        engineIds[_engine] = id;

        emit MarginEngineRegistered(_engine, id);
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
        (TokenType tokenType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = TokenIdUtil
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
}
