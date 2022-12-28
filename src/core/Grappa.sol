// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// interfaces
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IGrappa} from "../interfaces/IGrappa.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";
import {IMEPhysicalSettlement} from "../interfaces/IMEPhysicalSettlement.sol";

// librarise
import {BalanceUtil} from "../libraries/BalanceUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";

// constants and types
import "../config/types.sol";
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   Grappa
 * @author  @antoncoding, @dsshap
 * @dev     This contract serves as the registry of the system who system.
 */
contract Grappa is OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using BalanceUtil for Balance[];
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
            DerivativeType derivativeType,
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
     * @param _derivativeType DerivativeType enum
     * @param _settlementType SettlementType enum
     * @param _productId if of the product
     * @param _expiry timestamp of derivative expiry
     * @param _strike strike price of the derivative, with 6 decimals
     * @param _reserved allocated space for additional data
     */
    function getTokenId(
        DerivativeType _derivativeType,
        SettlementType _settlementType,
        uint40 _productId,
        uint256 _expiry,
        uint256 _strike,
        uint256 _reserved
    ) external pure returns (uint256 id) {
        id = TokenIdUtil.getTokenId(
            _derivativeType, _settlementType, _productId, uint64(_expiry), uint64(_strike), uint64(_reserved)
        );
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
        public
        nonReentrant
        returns (uint256 debt, uint256 payout)
    {
        optionToken.burnGrappaOnly(_account, _tokenId, _amount);

        Settlement memory settlement = _settle(_account, _tokenId, _amount);

        return (settlement.debt, settlement.payout);
    }

    /**
     * @notice burn array of option tokens and settles debts and payouts at expiry
     *
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     */
    function batchSettle(address _account, uint256[] memory _tokenIds, uint256[] memory _amounts)
        external
        nonReentrant
        returns (Balance[] memory debts, Balance[] memory payouts)
    {
        if (_tokenIds.length != _amounts.length) revert GP_WrongArgumentLength();

        if (_tokenIds.length == 0) return (debts, payouts);

        optionToken.batchBurnGrappaOnly(_account, _tokenIds, _amounts);

        for (uint256 i; i < _tokenIds.length;) {
            Settlement memory settlement = _settle(_account, _tokenIds[i], _amounts[i]);

            if (settlement.debt != 0) debts = _addToBalances(debts, settlement.debtAssetId, settlement.debt);

            if (settlement.payout != 0) payouts = _addToBalances(payouts, settlement.payoutAssetId, settlement.payout);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev calculate the debt & payout for one option token
     *
     * @param _tokenId  token id of option token
     * @param _amount   amount to settle
     *
     * @return settlement struct
     *
     */
    function getSettlement(uint256 _tokenId, uint64 _amount) public view returns (Settlement memory settlement) {
        settlement = _getSettlementPerToken(_tokenId);

        settlement.debt = settlement.debtPerToken * _amount;
        settlement.payout = settlement.payoutPerToken * _amount;

        unchecked {
            settlement.debt = settlement.debt / UNIT;
            settlement.payout = settlement.payout / UNIT;
        }
    }

    /**
     * @dev calculate the debts and payouts for array of options
     *
     * @param _tokenIds array of token id
     * @param _amounts  array of amount
     *
     * @return debts amounts owed
     * @return payouts amounts paid
     *
     */
    function batchGetSettlements(uint256[] memory _tokenIds, uint256[] memory _amounts)
        external
        view
        returns (Balance[] memory debts, Balance[] memory payouts)
    {
        for (uint256 i; i < _tokenIds.length;) {
            Settlement memory settlement = getSettlement(_tokenIds[i], _amounts[i].toUint64());

            uint256 debt = settlement.debt;
            uint256 payout = settlement.payout;

            if (debt != 0) debts = _addToBalances(debts, settlement.debtAssetId, debt);

            if (payout != 0) payouts = _addToBalances(payouts, settlement.payoutAssetId, payout);

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
    function checkEngineAccess(uint256 _tokenId, address _engine) external view {
        // create check engine access
        uint8 engineId = TokenIdUtil.parseEngineId(_tokenId);
        if (_engine != engines[engineId]) revert GP_Not_Authorized_Engine();
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
        if (_engine != engines[engineId]) revert GP_Not_Authorized_Engine();
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
        (DerivativeType derivativeType, SettlementType settlementType,, uint64 expiry, uint64 strikePrice, uint64 reserved) =
            _tokenId.parseTokenId();

        // check option type, strike and reserved
        // check that vanilla options doesnt have a reserved argument
        if (
            (settlementType == SettlementType.CASH)
                && (derivativeType == DerivativeType.CALL || derivativeType == DerivativeType.PUT) && (reserved != 0)
        ) {
            revert GP_BadCashSettledStrikes();
        }

        // debit spreads cannot be settled physically
        if (
            (settlementType == SettlementType.PHYSICAL)
                && (derivativeType == DerivativeType.CALL_SPREAD || derivativeType == DerivativeType.PUT_SPREAD)
        ) {
            revert GP_BadPhysicallySettledDerivative();
        }

        // physically settled must have a valid issuer ID
        if ((settlementType == SettlementType.PHYSICAL) && (reserved == 0)) revert GP_BadPhysicallySettledDerivative();

        // check that you cannot mint a "credit spread" token, reserved is used as a short strikePrice
        if (derivativeType == DerivativeType.CALL_SPREAD && (reserved < strikePrice)) revert GP_BadCashSettledStrikes();
        if (derivativeType == DerivativeType.PUT_SPREAD && (reserved > strikePrice)) revert GP_BadCashSettledStrikes();

        // check expiry
        if (expiry <= block.timestamp) revert GP_InvalidExpiry();
    }

    /**
     * @notice settles token
     *
     * @param _account  who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     * @return settlement struct
     */
    function _settle(address _account, uint256 _tokenId, uint256 _amount) internal returns (Settlement memory settlement) {
        settlement = getSettlement(_tokenId, _amount.toUint64());

        uint256 debt = settlement.debt;
        uint256 payout = settlement.payout;

        emit OptionSettled(_account, _tokenId, _amount, debt, payout);

        if (debt != 0 && payout != 0) {
            settlement.tokenId = _tokenId;
            settlement.tokenAmount = _amount;
            settlement.debtor = msg.sender;
            settlement.creditor = _account;

            IMEPhysicalSettlement(settlement.engine).settlePhysicalOption(settlement);
        } else if (payout != 0) {
            address payoutAsset = assets[settlement.payoutAssetId].addr;
            IMarginEngine(settlement.engine).sendPayoutValue(payoutAsset, _account, payout);
        }
    }

    /**
     * @dev calculate the debt and payout for one derivative token
     *
     * @param _tokenId  token id of derivative token
     *
     * @return settlement struct
     *
     */
    function _getSettlementPerToken(uint256 _tokenId) internal view returns (Settlement memory settlement) {
        (, SettlementType settlementType,, uint64 expiry,,) = TokenIdUtil.parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert GP_NotExpired();

        address engine = engines[_tokenId.parseEngineId()];

        if (settlementType == SettlementType.CASH) {
            settlement.payoutPerToken = IMarginEngine(engine).getCashSettlementPerToken(_tokenId);

            if (settlement.payoutPerToken != 0) settlement.payoutAssetId = _tokenId.parseCollateralId();
        } else if (settlementType == SettlementType.PHYSICAL) {
            settlement = IMEPhysicalSettlement(engine).getPhysicalSettlementPerToken(_tokenId);
        }

        settlement.engine = engine;
    }

    /**
     * @dev add an entry to array of Balance
     * @param payouts existing payout array
     * @param collateralId new collateralId
     * @param payout new payout
     */
    function _addToBalances(Balance[] memory payouts, uint8 collateralId, uint256 payout)
        internal
        pure
        returns (Balance[] memory)
    {
        if (payout == 0) return payouts;

        (bool found, uint256 index) = payouts.indexOf(collateralId);
        if (!found) {
            payouts = payouts.append(Balance(collateralId, payout.toUint80()));
        } else {
            payouts[index].amount += payout.toUint80();
        }

        return payouts;
    }
}
