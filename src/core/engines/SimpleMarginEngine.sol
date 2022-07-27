// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

// interfaces
import {IOracle} from "../../interfaces/IOracle.sol";
import {IGrappa} from "../../interfaces/IGrappa.sol";
import {IOptionToken} from "../../interfaces/IOptionToken.sol";
import {IMarginEngine} from "../../interfaces/IMarginEngine.sol";

// librarise
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";
import {SimpleMarginMath} from "./libraries/SimpleMarginMath.sol";
import {SimpleMarginLib} from "./libraries/SimpleMarginLib.sol";

// constants and types
import "../../config/types.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";

/**
 * @title   SimpleMarginEngine
 * @author  @antoncoding
 * @notice  SimpleMarginEngine is in charge of maintaining margin requirement for each "account"
            Users can deposit collateral into SimpleMarginEngine and mint optionTokens (debt) out of it.
            Interacts with OptionToken to mint / burn.
            Interacts with Oracle to read spot price for assets and vol.
 */
contract SimpleMarginEngine is IMarginEngine, Ownable {
    using SimpleMarginMath for SimpleMarginDetail;
    using SimpleMarginLib for Account;
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    IGrappa public immutable grappa;
    IOracle public immutable oracle;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => Account structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => Account) public marginAccounts;

    ///@dev mapping of productId to SimpleMargin Parameters
    mapping(uint32 => ProductMarginParams) public productParams;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _grappa, address _oracle) {
        grappa = IGrappa(_grappa);
        oracle = IOracle(_oracle);
    }

    /*///////////////////////////////////////////////////////////////
                                  Events
    //////////////////////////////////////////////////////////////*/
    event ProductConfigurationUpdated(
        uint32 productId,
        uint32 dUpper,
        uint32 dLower,
        uint32 rUpper,
        uint32 rLower,
        uint32 volMul
    );

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * todo: consider movomg this to viewer contract
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        Account memory account = marginAccounts[_subAccount];
        SimpleMarginDetail memory detail = _getAccountDetail(account);

        minCollateral = _getMinCollateral(detail);
    }

    function isAccountHealthy(address _subAccount) external view returns (bool) {
        return _isAccountHealthy(marginAccounts[_subAccount]);
    }

    /**
     * @notice  liquidate an account:
     *          burning the token the account is shorted (repay the debt),
     *          and get the collateral from the margin account.
     * @dev     expected to be called by liquidators
     */
    function liquidate(
        address _subAccount,
        uint256[] memory tokensToBurn,
        uint256[] memory amountsToBurn
    ) external returns (uint8[] memory, uint80[] memory) {
        uint256 repayCallAmount = amountsToBurn[0];
        uint256 repayPutAmount = amountsToBurn[1];

        Account memory account = marginAccounts[_subAccount];

        if (account.shortCallId != tokensToBurn[0]) revert MA_WrongIdToLiquidate();
        if (account.shortPutId != tokensToBurn[1]) revert MA_WrongIdToLiquidate();

        if (_isAccountHealthy(account)) revert MA_AccountIsHealthy();

        bool hasShortCall = account.shortCallAmount != 0;
        bool hasShortPut = account.shortPutAmount != 0;

        // compute portion of the collateral the liquidator is repaying, in BPS.
        // @note: expected to lost precision becuase of performing division before multiplication
        uint256 portionBPS;
        if (hasShortCall && hasShortPut) {
            // if the account is short call and put at the same time,
            // amounts to liquidate needs to be the same portion of short call and short put amount.
            uint256 callPortionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
            uint256 putPortionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
            if (callPortionBPS != putPortionBPS) revert MA_WrongRepayAmounts();
            portionBPS = callPortionBPS;
        } else if (hasShortCall) {
            // account only short call
            if (repayPutAmount != 0) revert MA_WrongRepayAmounts();
            portionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
        } else {
            // if account is underwater, it must have shortCall or shortPut. in this branch it will sure have shortPutAmount > 0;
            // account only short put
            if (repayCallAmount != 0) revert MA_WrongRepayAmounts();
            portionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
        }

        // update account's debt and perform "safe" external calls
        if (hasShortCall) {
            account.burnOption(account.shortCallId, uint64(repayCallAmount));
        }
        if (hasShortPut) {
            // cacheShortPutId = account.shortPutId;
            account.burnOption(account.shortPutId, uint64(repayPutAmount));
        }

        // update account's collateral
        // address collateral = grappa.assets(account.collateralId);
        uint80 collateralToPay = uint80((account.collateralAmount * portionBPS) / BPS);

        uint8[] memory ids = new uint8[](1);
        ids[0] = account.collateralId;

        // if liquidator is trying to remove more collateral than owned, this line will revert
        account.removeCollateral(collateralToPay);

        // write new accout to storage
        marginAccounts[_subAccount] = account;

        uint80[] memory amounts = new uint80[](1);
        amounts[0] = collateralToPay;

        return (ids, amounts);
    }

    // /**
    //  * @notice  alternative to liquidation:
    //  *          take over someone else's underwater account, top up collateral to make it healthy.
    //  *          effectively equivalent to mint + liquidate + add back collateral got from liquidation
    //  * @dev     expected to be called by liquidators
    //  * @param _subAccountToTakeOver account id to be moved
    //  * @param _newSubAccount new acount Id which will be linked to the margin account structure
    //  * @param _additionalCollateral additional collateral to top up
    //  */
    // function takeoverPosition(
    //     address _subAccountToTakeOver,
    //     address _newSubAccount,
    //     uint80 _additionalCollateral
    // ) external {
    //     Account memory account = marginAccounts[_subAccountToTakeOver];
    //     if (_isAccountHealthy(account)) revert MA_AccountIsHealthy();

    //     // make sure caller has access to the new account id.
    //     _assertCallerHasAccess(_newSubAccount);

    //     // update account structure.
    //     account.addCollateral(_additionalCollateral, account.collateralId);

    //     _assertAccountHealth(account);

    //     // migrate account storage: delete the old entry and write "account" to new account id
    //     delete marginAccounts[_subAccountToTakeOver];

    //     if (!marginAccounts[_newSubAccount].isEmpty()) revert MA_AccountIsNotEmpty();
    //     marginAccounts[_newSubAccount] = account;

    //     // perform external calls
    //     address collateral = grappa.assets(account.collateralId);
    //     IERC20(collateral).safeTransferFrom(msg.sender, address(this), _additionalCollateral);
    // }

    // /**
    //  * @notice  top up an account
    //  * @dev     expected to be call by account owner
    //  * @param   _subAccount sub account id to top up
    //  * @param   _collateralAmount sub account id to top up
    //  */
    // function topUp(address _subAccount, uint80 _collateralAmount) external {
    //     Account memory account = marginAccounts[_subAccount];
    //     // update account structure.
    //     account.addCollateral(_collateralAmount, account.collateralId);
    //     // store account object
    //     marginAccounts[_subAccount] = account;
    //     // external calls
    //     IERC20(grappa.assets(account.collateralId)).safeTransferFrom(msg.sender, address(this), _collateralAmount);
    // }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        _assertCallerHasAccess(_subAccount);

        if (!marginAccounts[_newSubAccount].isEmpty()) revert MA_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = marginAccounts[_subAccount];

        delete marginAccounts[_subAccount];
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
        uint32 _productId,
        uint32 _dUpper,
        uint32 _dLower,
        uint32 _rUpper,
        uint32 _rLower,
        uint32 _volMultiplier
    ) external onlyOwner {
        productParams[_productId] = ProductMarginParams({
            dUpper: _dUpper,
            dLower: _dLower,
            sqrtDUpper: uint32(FixedPointMathLib.sqrt(uint256(_dUpper))),
            sqrtDLower: uint32(FixedPointMathLib.sqrt(uint256(_dLower))),
            rUpper: _rUpper,
            rLower: _rLower,
            volMultiplier: _volMultiplier
        });

        emit ProductConfigurationUpdated(_productId, _dUpper, _dLower, _rUpper, _rLower, _volMultiplier);
    }

    /**
     * @dev calculate the payout for an expired option token
     *
     * @param _tokenId  token id of option token
     * @param _amount   amount to settle
     *
     * @return collateral asset to settle in
     * @return payout amount paid
     **/
    function getPayout(uint256 _tokenId, uint64 _amount) public view returns (address, uint256 payout) {
        (TokenType tokenType, uint32 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = TokenIdUtil
            .parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert MA_NotExpired();

        ProductAssets memory productAssets = _getProductAssets(productId);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = oracle.getPriceAtExpiry(productAssets.underlying, productAssets.strike, expiry);

        if (tokenType == TokenType.CALL) {
            cashValue = SimpleMarginMath.getCallCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = SimpleMarginMath.getCashValueCallDebitSpread(expiryPrice, longStrike, shortStrike);
        } else if (tokenType == TokenType.PUT) {
            cashValue = SimpleMarginMath.getPutCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = SimpleMarginMath.getCashValuePutDebitSpread(expiryPrice, longStrike, shortStrike);
        }

        // payout is denominated in strike asset (usually USD), with {UNIT_DECIMALS} decimals
        payout = cashValue.mulDivDown(_amount, UNIT);

        // the following logic convert payout amount if collateral is not strike:
        if (productAssets.collateral == productAssets.underlying) {
            // collateral is underlying. payout should be devided by underlying price
            payout = payout.mulDivDown(UNIT, expiryPrice);
        } else if (productAssets.collateral != productAssets.strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = oracle.getPriceAtExpiry(productAssets.collateral, productAssets.strike, expiry);
            payout = payout.mulDivDown(UNIT, collateralPrice);
        }

        return (productAssets.collateral, _convertDecimals(payout, UNIT_DECIMALS, productAssets.collateralDecimals));
    }

    /** ========================================================= **
     *                 * -------------------- *                    *
     *                 |  Actions  Functions  |                    *
     *                 * -------------------- *                    *
     *    These functions all update account struct memory and     *
     *    deal with burning / minting or transfering collateral    *
     ** ========================================================= **/

    /**
     * @dev pull token from user, increase collateral in account memory
            the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function addCollateral(
        address _subAccount,
        uint80 _amount,
        uint8 _collateralId
    ) external {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account structure in memory
        account.addCollateral(_amount, _collateralId);

        marginAccounts[_subAccount] = account;
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     */
    function removeCollateral(
        address _subAccount,
        uint8, /*_collateralId*/
        uint80 _amount
    ) external {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account structure in memory
        // todo: check collateral
        account.removeCollateral(_amount);

        marginAccounts[_subAccount] = account;
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     */
    function mintOption(
        address _subAccount,
        uint256 _optionId,
        uint64 _amount
    ) external {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account structure in memory
        account.mintOption(_optionId, _amount);

        // mint the real option token
        marginAccounts[_subAccount] = account;
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     */
    function burnOption(
        address _subAccount,
        uint256 _optionId,
        uint64 _amount
    ) external {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account structure in memory
        account.burnOption(_optionId, _amount);

        // mint the real option token
        marginAccounts[_subAccount] = account;
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     */
    function merge(address _subAccount, uint256 _optionId) external returns (uint64 burnAmount) {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account
        burnAmount = account.merge(_optionId);

        // mint the real option token
        marginAccounts[_subAccount] = account;
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     */
    function split(address _subAccount, TokenType tokenType) external returns (uint256 optionId, uint64 mintAmount) {
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        // update the account
        (optionId, mintAmount) = account.split(tokenType);

        marginAccounts[_subAccount] = account;
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     */
    function settleAtExpiry(address _subAccount) external {
        // clear the debt in account, and deduct the collateral with reservedPayout
        // this will NOT revert even if account has less collateral than it should have reserved for payout.
        // todo: only grappa
        Account memory account = marginAccounts[_subAccount];

        uint80 reservedPayout = _getPayoutFromAccount(account);

        // update the account
        account.settleAtExpiry(reservedPayout);

        marginAccounts[_subAccount] = account;
    }

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

    /**
     * @notice return if {_primary} address is the primary account for {_subAccount}
     */
    function _isPrimaryAccountFor(address _primary, address _subAccount) internal pure returns (bool) {
        return (uint160(_primary) | 0xFF) == (uint160(_subAccount) | 0xFF);
    }

    /**
     * @notice return if the calling address is eligible to access an subAccount address
     */
    function _assertCallerHasAccess(address _subAccount) internal view {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();
    }

    /**
     * @dev make sure account is above water
     */
    function _assertAccountHealth(Account memory account) internal view {
        if (!_isAccountHealthy(account)) revert MA_AccountUnderwater();
    }

    /**
     * @dev return whether if an account is healthy.
     * @param account account structure in memory
     * @return isHealthy true if account is in good condition, false if it's liquidatable
     */
    function _isAccountHealthy(Account memory account) internal view returns (bool isHealthy) {
        SimpleMarginDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = _getMinCollateral(detail);
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param detail account memory dtail
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function _getMinCollateral(SimpleMarginDetail memory detail) internal view returns (uint256 minCollateral) {
        ProductAssets memory product = _getProductAssets(detail.productId);

        // read spot price of the product, denominated in {UNIT_DECIMALS}.
        // Pass in 0 if margin account has not debt
        uint256 spotPrice;
        if (detail.productId != 0) spotPrice = oracle.getSpotPrice(product.underlying, product.strike);

        // need to pass in collateral/strike price. Pass in 0 if collateral is strike to save gas.
        uint256 collateralStrikePrice = 0;
        if (product.collateral == product.underlying) collateralStrikePrice = spotPrice;
        else if (product.collateral != product.strike) {
            collateralStrikePrice = oracle.getSpotPrice(product.collateral, product.strike);
        }

        uint256 minCollateralInUnit = detail.getMinCollateral(
            product,
            spotPrice,
            collateralStrikePrice,
            oracle.getVolIndex(),
            productParams[detail.productId]
        );

        minCollateral = _convertDecimals(minCollateralInUnit, UNIT_DECIMALS, product.collateralDecimals);
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _account account memory
     */
    function _getPayoutFromAccount(Account memory _account) internal view returns (uint80 reservedPayout) {
        (uint256 callPayout, uint256 putPayout) = (0, 0);
        if (_account.shortCallAmount > 0) (, callPayout) = getPayout(_account.shortCallId, _account.shortCallAmount);
        if (_account.shortPutAmount > 0) (, putPayout) = getPayout(_account.shortPutId, _account.shortPutAmount);
        return uint80(callPayout + putPayout);
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(Account memory account) internal pure returns (SimpleMarginDetail memory detail) {
        detail = SimpleMarginDetail({
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

        (, uint32 productId, uint64 expiry, , ) = TokenIdUtil.parseTokenId(commonId);
        detail.productId = productId;
        detail.expiry = expiry;
    }

    /**
     * @dev get a struct that stores all relevent token addresses, along with collateral asset decimals
     */
    function _getProductAssets(uint32 _productId) internal view returns (ProductAssets memory info) {
        (, address underlying, address strike, address collateral, uint8 collatDecimals) = grappa
            .getAssetsFromProductId(_productId);
        info.underlying = underlying;
        info.strike = strike;
        info.collateral = collateral;
        info.collateralDecimals = collatDecimals;
    }

    /**
     * @notice convert decimals
     *
     * @param  _amount      number to convert
     * @param _fromDecimals the decimals _amount has
     * @param _toDecimals   the target decimals
     *
     * @return _ number with _toDecimals decimals
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
