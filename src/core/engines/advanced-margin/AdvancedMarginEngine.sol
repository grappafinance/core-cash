// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";
import {IVolOracle} from "../../../interfaces/IVolOracle.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {AdvancedMarginMath} from "./AdvancedMarginMath.sol";
import {AdvancedMarginLib} from "./AdvancedMarginLib.sol";

// constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title   AdvancedMarginEngine
 * @author  @antoncoding
 * @notice  AdvancedMarginEngine is in charge of maintaining margin requirement for partial collateralized options
            Please see AdvancedMarginMath.sol for detailed partial collat calculation
            Interacts with OptionToken to mint / burn
            Interacts with grappa to fetch registered asset info
            Interacts with Oracle to read spot
            Interacts with VolOracle to read vol
 */
contract AdvancedMarginEngine is IMarginEngine, BaseEngine, Ownable {
    using AdvancedMarginMath for AdvancedMarginDetail;
    using AdvancedMarginLib for AdvancedMarginAccount;
    using SafeERC20 for IERC20;
    using NumberUtil for uint256;
    using FixedPointMathLib for uint256;
    using SafeCast for uint256;

    IVolOracle public immutable volOracle;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => AdvancedMarginAccount structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => AdvancedMarginAccount) public marginAccounts;

    ///@dev mapping of productId to AdvancedMargin Parameters
    mapping(uint40 => ProductMarginParams) public productParams;

    constructor(
        address _grappa,
        address _volOracle,
        address _optionToken
    ) BaseEngine(_grappa, _optionToken) {
        volOracle = IVolOracle(_volOracle);
    }

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event ProductConfigurationUpdated(
        uint40 productId,
        uint32 dUpper,
        uint32 dLower,
        uint32 rUpper,
        uint32 rLower,
        uint32 volMul
    );

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    function execute(address _subAccount, ActionArgs[] calldata actions) public override nonReentrant {
        _assertCallerHasAccess(_subAccount);

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else revert AM_UnsupportedAction();

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
        if (!_isAccountAboveWater(_subAccount)) revert BM_AccountUnderwater();
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        AdvancedMarginAccount memory account = marginAccounts[_subAccount];
        AdvancedMarginDetail memory detail = _getAccountDetail(account);

        minCollateral = _getMinCollateral(detail);
    }

    function isAccountHealthy(address _subAccount) external view returns (bool) {
        return _isAccountAboveWater(_subAccount);
    }

    /**
     * @notice  liquidate an account:
     *          burning the token the account is shorted (repay the debt),
     *          and get the collateral from the margin account.
     * @dev     expected to be called by liquidators
     * @param _subAccount account to liquidate
     * @param repayCallAmount amount of call to burn
     * @param repayPutAmount amounts of put to burn
     */
    function liquidate(
        address _subAccount,
        uint256 repayCallAmount,
        uint256 repayPutAmount
    ) external nonReentrant returns (address collateral, uint80 collateralToPay) {
        AdvancedMarginAccount memory account = marginAccounts[_subAccount];
        if (_isAccountAboveWater(_subAccount)) revert AM_AccountIsHealthy();

        bool hasShortCall = account.shortCallAmount != 0;
        bool hasShortPut = account.shortPutAmount != 0;

        // compute portion of the collateral the liquidator is repaying, in BPS.
        // @note: expected to lost precision becuase of performing division before multiplication
        uint256 portionBPS;
        unchecked {
            // use uncheck because
            // repayAmount * 1000000 cannot overflow uint256, also shortAmount > 0
            if (hasShortCall && hasShortPut) {
                // if the account is short call and put at the same time,
                // amounts to liquidate needs to be the same portion of short call and short put amount.

                uint256 callPortionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
                uint256 putPortionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
                if (callPortionBPS != putPortionBPS) revert AM_WrongRepayAmounts();
                portionBPS = callPortionBPS;
            } else if (hasShortCall) {
                // account only short call
                if (repayPutAmount != 0) revert AM_WrongRepayAmounts();
                portionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
            } else {
                // if account is underwater, it must have shortCall or shortPut. in this branch it will sure have shortPutAmount > 0;
                // account only short put
                if (repayCallAmount != 0) revert AM_WrongRepayAmounts();
                portionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
            }
        }

        // update account's debt and perform "safe" external calls
        if (hasShortCall) {
            optionToken.burn(msg.sender, account.shortCallId, repayCallAmount);
            marginAccounts[_subAccount].burnOption(account.shortCallId, repayCallAmount.toUint64());
        }
        if (hasShortPut) {
            optionToken.burn(msg.sender, account.shortPutId, repayPutAmount);
            marginAccounts[_subAccount].burnOption(account.shortPutId, repayPutAmount.toUint64());
        }

        // update account's collateral
        unchecked {
            collateralToPay = ((account.collateralAmount * portionBPS) / BPS).toUint80();
        }

        collateral = grappa.assets(account.collateralId).addr;

        // if liquidator is trying to remove more collateral than owned, this line will revert
        marginAccounts[_subAccount].removeCollateral(account.collateralId, collateralToPay);

        IERC20(collateral).safeTransfer(msg.sender, collateralToPay);
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();

        if (!marginAccounts[_newSubAccount].isEmpty()) revert AM_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = marginAccounts[_subAccount];

        delete marginAccounts[_subAccount];
    }

    function payCashValue(
        address _asset,
        address _recipient,
        uint256 _amount
    ) public override(BaseEngine, IMarginEngine) {
        BaseEngine.payCashValue(_asset, _recipient, _amount);
    }

    /**
     * @notice set the margin config for specific productId
     * @dev    expected to be used by Owner or governance
     * @param _productId product id
     * @param _dUpper (sec) max time to expiry to offer a collateral requirement discount
     * @param _dLower (sec) min time to expiry to offer a collateral requirement discount
     * @param _rUpper (BPS) discount ratio if the time to expiry is at the upper bound
     * @param _rLower (BPS) discount ratio if the time to expiry is at the lower bound
     * @param _volMultiplier (BPS) multiplier used to apply to vol from oracle
     */
    function setProductMarginConfig(
        uint40 _productId,
        uint32 _dUpper,
        uint32 _dLower,
        uint32 _rUpper,
        uint32 _rLower,
        uint32 _volMultiplier
    ) external onlyOwner {
        productParams[_productId] = ProductMarginParams({
            dUpper: _dUpper,
            dLower: _dLower,
            sqrtDUpper: uint32(uint256(_dUpper).sqrt()),
            sqrtDLower: uint32(uint256(_dLower).sqrt()),
            rUpper: _rUpper,
            rLower: _rLower,
            volMultiplier: _volMultiplier
        });

        emit ProductConfigurationUpdated(_productId, _dUpper, _dLower, _rUpper, _rLower, _volMultiplier);
    }

    /** ========================================================= **
     *               Override Sate changing functions             *
     ** ========================================================= **/

    function _addCollateralToAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {
        marginAccounts[_subAccount].addCollateral(collateralId, amount);
    }

    function _removeCollateralFromAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {
        marginAccounts[_subAccount].removeCollateral(collateralId, amount);
    }

    function _increaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        marginAccounts[_subAccount].mintOption(tokenId, amount);
    }

    function _decreaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        marginAccounts[_subAccount].burnOption(tokenId, amount);
    }

    function _mergeLongIntoSpread(
        address _subAccount,
        uint256 shortTokenId,
        uint256 longTokenId,
        uint64 amount
    ) internal override {
        marginAccounts[_subAccount].merge(shortTokenId, longTokenId, amount);
    }

    function _splitSpreadInAccount(
        address _subAccount,
        uint256 spreadId,
        uint64 amount
    ) internal override {
        marginAccounts[_subAccount].split(spreadId, amount);
    }

    function _settleAccount(address _subAccount, uint80 payout) internal override {
        marginAccounts[_subAccount].settleAtExpiry(payout);
    }

    /** ========================================================= **
                            Override view functions
     ** ========================================================= **/

    /**
     * @dev return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view override returns (bool isHealthy) {
        AdvancedMarginAccount memory account = marginAccounts[_subAccount];
        AdvancedMarginDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = _getMinCollateral(detail);
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view override returns (uint80 payout) {
        (uint256 callPayout, uint256 putPayout) = (0, 0);
        AdvancedMarginAccount memory account = marginAccounts[_subAccount];
        if (account.shortCallAmount > 0)
            (, , callPayout) = grappa.getPayout(account.shortCallId, account.shortCallAmount);
        if (account.shortPutAmount > 0) (, , putPayout) = grappa.getPayout(account.shortPutId, account.shortPutAmount);
        return (callPayout + putPayout).toUint80();
    }

    /** ========================================================= **
                            Internal view functions
     ** ========================================================= **/

    /**
     * @notice get minimum collateral needed for a margin account
     * @param detail account memory dtail
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function _getMinCollateral(AdvancedMarginDetail memory detail) internal view returns (uint256 minCollateral) {
        ProductDetails memory product = _getProductDetails(detail.productId);

        // read spot price of the product, denominated in {UNIT_DECIMALS}.
        // Pass in 0 if margin account has not debt
        uint256 spotPrice;
        uint256 vol;
        if (detail.productId != 0) {
            spotPrice = IOracle(product.oracle).getSpotPrice(product.underlying, product.strike);
            vol = volOracle.getImpliedVol(product.underlying);
        }

        // need to pass in collateral/strike price. Pass in 0 if collateral is strike to save gas.
        uint256 collateralStrikePrice = 0;
        if (product.collateral == product.underlying) collateralStrikePrice = spotPrice;
        else if (product.collateral != product.strike) {
            collateralStrikePrice = IOracle(product.oracle).getSpotPrice(product.collateral, product.strike);
        }

        uint256 minCollateralInUnit = detail.getMinCollateral(
            product,
            spotPrice,
            collateralStrikePrice,
            vol,
            productParams[detail.productId]
        );

        minCollateral = minCollateralInUnit.convertDecimals(UNIT_DECIMALS, product.collateralDecimals);
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(AdvancedMarginAccount memory account)
        internal
        pure
        returns (AdvancedMarginDetail memory detail)
    {
        detail = AdvancedMarginDetail({
            putAmount: account.shortPutAmount,
            callAmount: account.shortCallAmount,
            longPutStrike: 0,
            shortPutStrike: 0,
            longCallStrike: 0,
            shortCallStrike: 0,
            expiry: 0,
            collateralAmount: account.collateralAmount,
            productId: 0
        });

        // if it contains a call
        if (account.shortCallId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = TokenIdUtil.parseTokenId(account.shortCallId);
            // the short position of the account is the long of the minted optionToken
            detail.shortCallStrike = longStrike;
            detail.longCallStrike = shortStrike;
        }

        // if it contains a put
        if (account.shortPutId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = TokenIdUtil.parseTokenId(account.shortPutId);

            // the short position of the account is the long of the minted optionToken
            detail.shortPutStrike = longStrike;
            detail.longPutStrike = shortStrike;
        }

        // parse common field
        // use the OR operator, so as long as one of shortPutId or shortCallId is non-zero, got reflected here
        uint256 commonId = account.shortPutId | account.shortCallId;

        (, uint40 productId, uint64 expiry, , ) = TokenIdUtil.parseTokenId(commonId);
        detail.productId = productId;
        detail.expiry = expiry;
    }

    /**
     * @dev get a struct that stores all relevent token addresses, along with collateral asset decimals
     */
    function _getProductDetails(uint40 _productId) internal view returns (ProductDetails memory info) {
        (address oracle, , address underlying, , address strike, , address collateral, uint8 collatDecimals) = grappa
            .getDetailFromProductId(_productId);
        info.oracle = oracle;
        info.underlying = underlying;
        info.strike = strike;
        info.collateral = collateral;
        info.collateralDecimals = collatDecimals;
    }
}
