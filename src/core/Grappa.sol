// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// interfaces
import {ICashSettlement} from "../interfaces/ICashSettlement.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IGrappa} from "../interfaces/IGrappa.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IPhysicalSettlement} from "../interfaces/IPhysicalSettlement.sol";

// librarise
import {BalanceUtil} from "../libraries/BalanceUtil.sol";
import {MoneynessLib} from "../libraries/MoneynessLib.sol";
import {NumberUtil} from "../libraries/NumberUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";

// constants and types
import "../config/constants.sol";
import "../config/enums.sol";
import "../config/errors.sol";
import "../config/types.sol";

/**
 * @title   Grappa
 * @author  @antoncoding, @dsshap
 * @dev     This contract serves as the registry of the system who system.
 */
contract Grappa is OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using BalanceUtil for Balance[];
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using ProductIdUtil for uint40;
    using SafeCast for uint256;
    using TokenIdUtil for uint256;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;

    /*///////////////////////////////////////////////////////////////
                         State Variables V1
    //////////////////////////////////////////////////////////////*/

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint8 public nextAssetId;

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint8 public nextengineId;

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint8 public nextOracleId;

    /// @dev assetId => asset address
    mapping(uint8 => AssetDetail) public assets;

    /// @dev engineId => margin engine address
    mapping(uint8 => address) public engines;

    /// @dev oracleId => oracle address
    mapping(uint8 => address) public oracles;

    /// @dev address => assetId
    mapping(address => uint8) public assetIds;

    /// @dev address => engineId
    mapping(address => uint8) public engineIds;

    /// @dev address => oracleId
    mapping(address => uint8) public oracleIds;

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event OptionSettled(address account, uint256 tokenId, uint256 amountSettled, uint256 debt, uint256 payout);
    event AssetRegistered(address asset, uint8 id);
    event MarginEngineRegistered(address engine, uint8 id);
    event OracleRegistered(address oracle, uint8 id);

    /*///////////////////////////////////////////////////////////////
                Constructor for implementation Contract
    //////////////////////////////////////////////////////////////*/

    /// @dev set immutables in constructor
    /// @dev also set the implemention contract to initialized = true
    constructor(address _optionToken) initializer {
        optionToken = IOptionToken(_optionToken);
    }

    /*///////////////////////////////////////////////////////////////
                            Initializer
    //////////////////////////////////////////////////////////////*/

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init_unchained();
    }

    /*///////////////////////////////////////////////////////////////
                    Override Upgrade Permission
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Upgradable by the owner.
     *
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override {
        _checkOwner();
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
            address oracle,
            address engine,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            uint8 strikeDecimals,
            address collateral,
            uint8 collateralDecimals
        )
    {
        (uint8 oracleId, uint8 engineId, uint8 underlyingId, uint8 strikeId, uint8 collateralId) =
            ProductIdUtil.parseProductId(_productId);
        AssetDetail memory underlyingDetail = assets[underlyingId];
        AssetDetail memory strikeDetail = assets[strikeId];
        AssetDetail memory collateralDetail = assets[collateralId];
        return (
            oracles[oracleId],
            engines[engineId],
            underlyingDetail.addr,
            underlyingDetail.decimals,
            strikeDetail.addr,
            strikeDetail.decimals,
            collateralDetail.addr,
            collateralDetail.decimals
        );
    }

    /**
     * @dev parse token id into composing option details
     * @param _tokenId product id
     */
    function getDetailFromTokenId(uint256 _tokenId)
        external
        pure
        returns (
            TokenType tokenType,
            SettlementType settlementType,
            uint40 productId,
            uint64 expiry,
            uint64 strike,
            uint64 reserved
        )
    {
        return TokenIdUtil.parseTokenId(_tokenId);
    }

    /**
     * @notice    get product id from underlying, strike and collateral address
     * @dev       function will still return even if some of the assets are not registered
     * @param _underlying  underlying address
     * @param _strike      strike address
     * @param _collateral  collateral address
     */
    function getProductId(address _oracle, address _engine, address _underlying, address _strike, address _collateral)
        external
        view
        returns (uint40 id)
    {
        id = ProductIdUtil.getProductId(
            oracleIds[_oracle], engineIds[_engine], assetIds[_underlying], assetIds[_strike], assetIds[_collateral]
        );
    }

    /**
     * @notice    get token id from type, productId, expiry, strike
     * @dev       function will still return even if some of the assets are not registered
     * @param _optionType TokenType enum
     * @param _settlementType SettlementType enum
     * @param _productId if of the product
     * @param _expiry timestamp of option expiry
     * @param _strike strike price of the option, with 6 decimals
     * @param _reserved allocated space for additional data
     */
    function getTokenId(
        TokenType _optionType,
        SettlementType _settlementType,
        uint40 _productId,
        uint256 _expiry,
        uint256 _strike,
        uint256 _reserved
    ) external pure returns (uint256 id) {
        id = TokenIdUtil.getTokenId(_optionType, _settlementType, _productId, uint64(_expiry), uint64(_strike), uint64(_reserved));
    }

    /**
     * @notice burn option token and settles debt and payout at expiry
     *
     * @param _account  who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return debt amount owed
     * @return payout amount receiving
     */
    function settle(address _account, uint256 _tokenId, uint256 _amount)
        external
        nonReentrant
        returns (uint256 debt, uint256 payout)
    {
        optionToken.burnGrappaOnly(_account, _tokenId, _amount);

        (debt, payout) = _settle(_account, _tokenId, _amount.toUint64());
    }

    /**
     * @notice burn array of option tokens and settles debts and payouts at expiry
     *
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts array of amounts to burn
     */
    function batchSettle(address _account, uint256[] memory _tokenIds, uint256[] memory _amounts) external nonReentrant {
        if (_tokenIds.length != _amounts.length) revert GP_WrongArgumentLength();

        optionToken.batchBurnGrappaOnly(_account, _tokenIds, _amounts);

        for (uint256 i; i < _tokenIds.length;) {
            _settle(_account, _tokenIds[i], _amounts[i].toUint64());

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev calculate the debt & payout for one token
     *
     * @param _tokenId  id of token
     * @param _amount   amount to settle
     * @return debt owed
     * @return payout credited
     *
     */
    function getSettlement(uint256 _tokenId, uint256 _amount) external view returns (uint256 debt, uint256 payout) {
        if (_tokenId.isCash()) {
            (,, payout) = _getCashSettlement(_tokenId, _amount.toUint64());
        } else if (_tokenId.isPhysical()) {
            Settlement memory settlement = _getPhysicalSettlement(_tokenId, _amount.toUint64());

            return (settlement.debt, settlement.payout);
        }
    }

    /**
     * @notice calculate the debts and payouts at expiry for an array of tokens
     *
     * @param _tokenIds array of tokenIds
     * @param _amounts array of amounts
     */
    function getBatchSettlement(uint256[] memory _tokenIds, uint256[] memory _amounts)
        public
        view
        returns (Balance[] memory debts, Balance[] memory payouts)
    {
        if (_tokenIds.length != _amounts.length) revert GP_WrongArgumentLength();

        if (_tokenIds.length == 0) return (debts, payouts);

        for (uint256 i; i < _tokenIds.length;) {
            uint8 payoutId;
            uint256 payout;

            uint256 _tokenId = _tokenIds[i];

            if (_tokenId.isCash()) {
                (,, payout) = _getCashSettlement(_tokenId, _amounts[i].toUint64());

                payoutId = _tokenId.parseCollateralId();
            } else if (_tokenId.isPhysical()) {
                Settlement memory settlement = _getPhysicalSettlement(_tokenId, _amounts[i].toUint64());

                payoutId = settlement.payoutId;
                payout = settlement.payout;

                if (settlement.debt != 0) {
                    debts = _addToBalances(debts, settlement.debtId, settlement.debt);
                }
            }

            if (payout != 0) payouts = _addToBalances(payouts, payoutId, payout);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev revert if _engine doesn't have access to mint / burn a tokenId;
     * @param _tokenId tokenid
     * @param _engine address intending to mint / burn
     */
    function checkEngineAccess(uint256 _tokenId, address _engine) public view {
        // create check engine access
        uint8 engineId = TokenIdUtil.parseEngineId(_tokenId);
        if (_engine != engines[engineId]) revert GP_NotAuthorizedEngine();
    }

    /**
     * @dev revert if _engine doesn't have access to mint or the tokenId is invalid.
     * @param _tokenId tokenid
     * @param _engine address intending to mint / burn
     */
    function checkEngineAccessAndTokenId(uint256 _tokenId, address _engine) external view {
        // check tokenId
        _isValidTokenIdToMint(_tokenId);

        //  check engine access
        uint8 engineId = _tokenId.parseEngineId();
        if (_engine != engines[engineId]) revert GP_NotAuthorizedEngine();
    }

    /*///////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev register an asset to be used as strike/underlying
     * @param _asset address to add
     *
     */
    function registerAsset(address _asset) external returns (uint8 id) {
        _checkOwner();

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
     *
     */
    function registerEngine(address _engine) external returns (uint8 id) {
        _checkOwner();

        if (engineIds[_engine] != 0) revert GP_EngineAlreadyRegistered();

        id = ++nextengineId;
        engines[id] = _engine;

        engineIds[_engine] = id;

        emit MarginEngineRegistered(_engine, id);
    }

    /**
     * @dev register an oracle to report prices
     * @param _oracle address of the new oracle
     *
     */
    function registerOracle(address _oracle) external returns (uint8 id) {
        _checkOwner();

        if (oracleIds[_oracle] != 0) revert GP_OracleAlreadyRegistered();

        // this is a soft check on whether an oracle is suitable to be used.
        if (IOracle(_oracle).maxDisputePeriod() > MAX_DISPUTE_PERIOD) revert GP_BadOracle();

        id = ++nextOracleId;
        oracles[id] = _oracle;

        oracleIds[_oracle] = id;

        emit OracleRegistered(_oracle, id);
    }

    /* =====================================
     *          Internal Functions
     * ====================================**/

    /**
     * @dev make sure that the tokenId make sense
     */
    function _isValidTokenIdToMint(uint256 _tokenId) internal view {
        (TokenType tokenType, SettlementType settlementType,, uint64 expiry, uint64 strikePrice, uint64 reserved) =
            _tokenId.parseTokenId();

        // check option type, strike and reserved
        // check that vanilla options doesnt have a reserved argument
        if (
            (settlementType == SettlementType.CASH) && (tokenType == TokenType.CALL || tokenType == TokenType.PUT)
                && (reserved != 0)
        ) {
            revert GP_BadCashSettledStrikes();
        }

        // debit spreads cannot be settled physically
        if (
            (settlementType == SettlementType.PHYSICAL)
                && (tokenType == TokenType.CALL_SPREAD || tokenType == TokenType.PUT_SPREAD)
        ) {
            revert GP_BadPhysicalSettlementToken();
        }

        // check that you cannot mint a "credit spread" token, reserved is used as a short strikePrice
        if (tokenType == TokenType.CALL_SPREAD && (reserved < strikePrice)) revert GP_BadCashSettledStrikes();
        if (tokenType == TokenType.PUT_SPREAD && (reserved > strikePrice)) revert GP_BadCashSettledStrikes();

        // check expiry
        if (expiry <= block.timestamp) revert GP_InvalidExpiry();
    }

    /**
     * @notice settles token
     * @param _account  who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return debt what is owed
     * @return payout what is being received
     */
    function _settle(address _account, uint256 _tokenId, uint64 _amount) internal returns (uint256 debt, uint256 payout) {
        if (_tokenId.isCash()) payout = _settleCashToken(_account, _tokenId, _amount);
        else if (_tokenId.isPhysical()) return _settlePhysicalToken(_account, _tokenId, _amount);
    }

    /**
     * @notice settles cash token
     * @param _account  who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return payout what is being received
     */
    function _settleCashToken(address _account, uint256 _tokenId, uint64 _amount) internal returns (uint256 payout) {
        address engine;
        address collateral;

        (engine, collateral, payout) = _getCashSettlement(_tokenId, _amount);

        emit OptionSettled(_account, _tokenId, _amount, 0, payout);

        // option owner gets collateral
        if (payout != 0) ICashSettlement(engine).sendPayoutValue(collateral, _account, payout);
    }

    /**
     * @notice settles physical token
     *
     * @param _account  who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return debt what is owed
     * @return payout what is being received
     */
    function _settlePhysicalToken(address _account, uint256 _tokenId, uint64 _amount)
        internal
        returns (uint256 debt, uint256 payout)
    {
        Settlement memory settlement = _getPhysicalSettlement(_tokenId, _amount);

        emit OptionSettled(_account, _tokenId, _amount, settlement.debt, settlement.payout);

        if (settlement.debt > 0) {
            IPhysicalSettlement engine = IPhysicalSettlement(settlement.engine);

            engine.handleExercise(_tokenId, settlement.debt, settlement.payout);
            // pull debt asset from msg.sender to engine
            engine.receiveDebtValue(assets[settlement.debtId].addr, msg.sender, settlement.debt);
            // make the engine pay out payout amount
            engine.sendPayoutValue(assets[settlement.payoutId].addr, _account, settlement.payout);
        }

        return (settlement.debt, settlement.payout);
    }

    /**
     * @dev returns payout for cash settled tokens
     * @param _tokenId  id of token
     * @param _amount   amount to settle
     * @return engine engine paying out
     * @return collateral asset of payout
     * @return payout what is being received
     *
     */
    function _getCashSettlement(uint256 _tokenId, uint64 _amount)
        internal
        view
        returns (address engine, address collateral, uint256 payout)
    {
        uint256 payoutPerToken;
        (engine, collateral, payoutPerToken) = _getCashSettlementPerToken(_tokenId);

        payout = payoutPerToken * _amount;

        unchecked {
            payout = payout / UNIT;
        }
    }

    /**
     * @dev returns settlement structure for physically settled tokens
     * @param _tokenId  id of token
     * @param _amount   amount to settle
     * @return settlement struct
     *
     */
    function _getPhysicalSettlement(uint256 _tokenId, uint64 _amount) internal view returns (Settlement memory settlement) {
        settlement = _getPhysicalSettlementPerToken(_tokenId);

        settlement.debt = settlement.debt * _amount;
        settlement.payout = settlement.payout * _amount;

        unchecked {
            settlement.debt = settlement.debt / UNIT;
            settlement.payout = settlement.payout / UNIT;
        }
    }

    /**
     * @dev calculate the cash settled payout for one option token
     * @param _tokenId  token id of option token
     * @return payoutPerToken amount paid
     */
    function _getCashSettlementPerToken(uint256 _tokenId)
        internal
        view
        virtual
        returns (address, address, uint256 payoutPerToken)
    {
        (TokenType tokenType,, uint40 productId, uint64 expiry, uint64 strikePrice, uint64 reserved) =
            TokenIdUtil.parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert GP_NotExpired();

        (address oracle, address engine, address underlying,, address strike,, address collateral, uint8 collateralDecimals) =
            getDetailFromProductId(productId);

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = _getCashSettlementPrice(oracle, underlying, strike, expiry);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;
        if (tokenType == TokenType.CALL) {
            cashValue = MoneynessLib.getCallCashValue(expiryPrice, strikePrice);
        } else if (tokenType == TokenType.PUT) {
            cashValue = MoneynessLib.getPutCashValue(expiryPrice, strikePrice);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitCallSpread(expiryPrice, strikePrice, reserved);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitPutSpread(expiryPrice, strikePrice, reserved);
        }

        // the following logic convert cash value (amount worth) if collateral is not strike:
        if (collateral == underlying) {
            // collateral is underlying. payout should be devided by underlying price
            cashValue = cashValue.mulDivDown(UNIT, expiryPrice);
        } else if (collateral != strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = _getCashSettlementPrice(oracle, collateral, strike, expiry);
            cashValue = cashValue.mulDivDown(UNIT, collateralPrice);
        }

        payoutPerToken = cashValue.convertDecimals(UNIT_DECIMALS, collateralDecimals);

        return (engine, collateral, payoutPerToken);
    }

    /**
     * @dev calculate the debt and payout for one physically settled option token
     * @param _tokenId  token id of option token
     * @return settlement struct
     */
    function _getPhysicalSettlementPerToken(uint256 _tokenId) internal view virtual returns (Settlement memory settlement) {
        (TokenType tokenType,, uint40 productId, uint64 expiry, uint64 strikePrice,) = _tokenId.parseTokenId();

        if (block.timestamp < expiry) revert GP_NotExpired();

        (, uint8 engineId, uint8 underlyingId, uint8 strikeId,) = ProductIdUtil.parseProductId(productId);

        // settlement window closed: you get nothing
        IPhysicalSettlement engine = IPhysicalSettlement(engines[engineId]);
        if (block.timestamp >= expiry + engine.getSettlementWindow()) return settlement;

        // puts can only be collateralized in strike
        uint256 strikeAmount = uint256(strikePrice).convertDecimals(UNIT_DECIMALS, assets[strikeId].decimals);

        // calls can only be collateralized in underlying
        uint256 underlyingAmount = UNIT.convertDecimals(UNIT_DECIMALS, assets[underlyingId].decimals);

        settlement.engine = engines[engineId];

        if (tokenType == TokenType.CALL) {
            settlement.debtId = strikeId;
            settlement.debt = strikeAmount;

            settlement.payoutId = underlyingId;
            settlement.payout = underlyingAmount;
        } else if (tokenType == TokenType.PUT) {
            settlement.debtId = underlyingId;
            settlement.debt = underlyingAmount;

            settlement.payoutId = strikeId;
            settlement.payout = strikeAmount;
        }
    }

    /**
     * @dev check settlement price is finalized from oracle, and return price
     * @param _oracle oracle contract address
     * @param _base base asset (ETH is base asset while requesting ETH / USD)
     * @param _quote quote asset (USD is base asset while requesting ETH / USD)
     * @param _expiry expiry timestamp
     */
    function _getCashSettlementPrice(address _oracle, address _base, address _quote, uint256 _expiry)
        internal
        view
        returns (uint256)
    {
        (uint256 price, bool isFinalized) = IOracle(_oracle).getPriceAtExpiry(_base, _quote, _expiry);
        if (!isFinalized) revert GP_PriceNotFinalized();
        return price;
    }

    /**
     * @dev add an entry to array of Balance
     * @param _payouts existing payout array
     * @param _collateralId new collateralId
     * @param _payout new payout
     */
    function _addToBalances(Balance[] memory _payouts, uint8 _collateralId, uint256 _payout)
        internal
        pure
        returns (Balance[] memory)
    {
        (bool found, uint256 index) = _payouts.indexOf(_collateralId);

        uint80 payout = _payout.toUint80();

        if (!found) _payouts = _payouts.append(Balance(_collateralId, payout));
        else _payouts[index].amount += payout;

        return _payouts;
    }
}
