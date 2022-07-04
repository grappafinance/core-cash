// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {IOptionToken} from "src/interfaces/IOptionToken.sol";

import {TokenIdUtil} from "src/libraries/TokenIdUtil.sol";
import {SimpleMarginMath} from "./libraries/SimpleMarginMath.sol";
import {SimpleMarginLib} from "./libraries/SimpleMarginLib.sol";

import {Settlement} from "src/core/Settlement.sol";

import "src/config/types.sol";
import "src/config/enums.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

/**
 * @title   MarginAccount
 * @author  antoncoding
 * @notice  MarginAccount is in charge of maintaining margin requirement for each "account"
            Users can deposit collateral into MarginAccount and mint optionTokens (debt) out of it.
            Interacts with OptionToken to mint / burn.
            Interacts with Oracle to read spot price / and vol.
 */
contract MarginAccount is ReentrancyGuard, Settlement {
    using SimpleMarginMath for MarginAccountDetail;
    using SimpleMarginLib for Account;
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => Account structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => Account) public marginAccounts;

    ///@dev maskedAccount => operator => authorized
    ///     every account can authorize any amount of addresses to modify all accounts he controls.
    mapping(uint160 => mapping(address => bool)) public authorized;

    mapping(uint32 => ProductMarginParams) public productParams;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _optionToken, address _oracle) Settlement(_optionToken, _oracle) {}

    /**
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        Account memory account = marginAccounts[_subAccount];
        MarginAccountDetail memory detail = _getAccountDetail(account);

        minCollateral = _getMinCollateral(detail);
    }

    /**
     * @notice  execute array of actions on an account
     * @dev     expected to be called by account owners.
     */
    function execute(address _subAccount, ActionArgs[] calldata actions) external nonReentrant {
        _assertCallerHasAccess(_subAccount);
        Account memory account = marginAccounts[_subAccount];

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(account, actions[i].data, _subAccount);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(account, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(account, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(account, actions[i].data, _subAccount);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(account, actions[i].data, _subAccount);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(account, actions[i].data);

            // increase i without checking overflow
            unchecked {
                i++;
            }
        }
        _assertAccountHealth(account);
        marginAccounts[_subAccount] = account;
    }

    /**
     * @notice  liquidate an account:
     *          burning the token the account is shorted (repay the debt),
     *          and get the collateral from the margin account.
     * @dev     expected to be called by liquidators
     */
    function liquidate(
        address _subAccount,
        uint64 _repayCallAmount,
        uint64 _repayPutAmount
    ) external {
        Account memory account = marginAccounts[_subAccount];
        if (_isAccountHealthy(account)) revert MA_AccountIsHealthy();

        bool hasShortCall = account.shortCallAmount != 0;
        bool hasShortPut = account.shortPutAmount != 0;

        // compute portion of the collateral the liquidator is repaying, in BPS.
        uint256 portionBPS;
        if (hasShortCall && hasShortPut) {
            // if the account is short call and put at the same time,
            // amounts to liquidate needs to be the same portion of short call and short put amount.
            uint256 callPortionBPS = (_repayCallAmount * BPS) / account.shortCallAmount;
            uint256 putPortionBPS = (_repayPutAmount * BPS) / account.shortPutAmount;
            if (callPortionBPS != putPortionBPS) revert MA_WrongRepayAmounts();
            portionBPS = callPortionBPS;
        } else if (hasShortCall) {
            // account only short call
            if (_repayPutAmount != 0) revert MA_WrongRepayAmounts();
            portionBPS = (_repayCallAmount * BPS) / account.shortCallAmount;
        } else {
            // if account is underwater, it must have shortCall or shortPut. in this branch it will sure have shortPutAmount > 0;
            // account only short put
            if (_repayCallAmount != 0) revert MA_WrongRepayAmounts();
            portionBPS = (_repayPutAmount * BPS) / account.shortPutAmount;
        }

        address collateral = address(assets[account.collateralId].addr);
        uint80 collateralToPay = uint80((account.collateralAmount * portionBPS) / BPS);

        // update account structure.
        // if liquidator is trying to remove more collateral than owned, this line will revert
        account.removeCollateral(collateralToPay);
        if (hasShortCall) {
            // external call: burn token. should be safe to call because it doens't trigger reentrancy
            // we do it here to save gas, otherwise we might need to cach shortCallId
            optionToken.burn(msg.sender, account.shortCallId, _repayCallAmount);

            // cacheShortCallId = account.shortCallId;
            account.burnOption(account.shortCallId, _repayCallAmount);
        }
        if (hasShortPut) {
            // external call: burn token. should be safe to call because it doens't trigger reentrancy
            // we do it here to save gas, otherwise we might need to cach shortPutId
            optionToken.burn(msg.sender, account.shortPutId, _repayPutAmount);

            // cacheShortPutId = account.shortPutId;
            account.burnOption(account.shortPutId, _repayPutAmount);
        }

        // write new accout to storage
        marginAccounts[_subAccount] = account;

        // extenal calls: transfer collateral
        IERC20(collateral).safeTransfer(msg.sender, collateralToPay);
    }

    /**
     * @notice  alternative to liquidation:
     *          take over someone else's underwater account, top up collateral to make it healthy.
     *          effectively equivalent to mint + liquidate + add back collateral got from liquidation
     * @dev     expected to be called by liquidators
     * @param _subAccountToTakeOver account id to be moved
     * @param _newSubAccount new acount Id which will be linked to the margin account structure
     * @param _additionalCollateral additional collateral to top up
     */
    function takeoverPosition(
        address _subAccountToTakeOver,
        address _newSubAccount,
        uint80 _additionalCollateral
    ) external {
        Account memory account = marginAccounts[_subAccountToTakeOver];
        if (_isAccountHealthy(account)) revert MA_AccountIsHealthy();

        // make sure caller has access to the new account id.
        _assertCallerHasAccess(_newSubAccount);

        // update account structure.
        account.addCollateral(_additionalCollateral, account.collateralId);

        _assertAccountHealth(account);

        // migrate account storage: delete the old entry and write "account" to new account id
        delete marginAccounts[_subAccountToTakeOver];

        if (!marginAccounts[_newSubAccount].isEmpty()) revert MA_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = account;

        // perform external calls
        address collateral = address(assets[account.collateralId].addr);
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), _additionalCollateral);
    }

    /**
     * @notice  top up an account
     * @dev     expected to be call by account owner
     * @param   _subAccount sub account id to top up
     * @param   _collateralAmount sub account id to top up
     */
    function topUp(address _subAccount, uint80 _collateralAmount) external {
        Account memory account = marginAccounts[_subAccount];
        // update account structure.
        account.addCollateral(_collateralAmount, account.collateralId);
        // store account object
        marginAccounts[_subAccount] = account;
        // external calls
        IERC20(address(assets[account.collateralId].addr)).safeTransferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        _assertCallerHasAccess(_subAccount);

        if (!marginAccounts[_newSubAccount].isEmpty()) revert MA_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = marginAccounts[_subAccount];

        delete marginAccounts[_subAccount];
    }

    /**
     * @notice  grant or revoke an account access to all your sub-accounts
     * @dev     expected to be call by account owner
     *          usually user should only give access to helper contracts
     */
    function setAccountAccess(address _account, bool _isAuthorized) external {
        authorized[uint160(msg.sender) | 0xFF][_account] = _isAuthorized;
    }

    /**
     * @notice set the margin config for specific productId
     * @dev    expected to be used by Owner or governance
     * @param _productId product id
     * @param _discountPeriodUpperBound (sec) max time to expiry to offer a collateral requirement discount
     * @param _discountPeriodLowerBound (sec) min time to expiry to offer a collateral requirement discount
     * @param _discountRatioUpperBound (BPS) discount ratio if the time to expiry is at the upper bound
     * @param _discountRatioLowerBound (BPS) discount ratio if the time to expiry is at the lower bound
     * @param _volMultiplier (BPS) spot shock
     */
    function setProductMarginConfig(
        uint32 _productId,
        uint32 _discountPeriodUpperBound,
        uint32 _discountPeriodLowerBound,
        uint32 _discountRatioUpperBound,
        uint32 _discountRatioLowerBound,
        uint32 _volMultiplier
    ) external onlyOwner {
        productParams[_productId] = ProductMarginParams({
            discountPeriodUpperBound: _discountPeriodUpperBound,
            discountPeriodLowerBound: _discountPeriodLowerBound,
            sqrtMaxDiscountPeriod: uint32(FixedPointMathLib.sqrt(uint256(_discountPeriodUpperBound))),
            sqrtMinDiscountPeriod: uint32(FixedPointMathLib.sqrt(uint256(_discountPeriodLowerBound))),
            discountRatioUpperBound: _discountRatioUpperBound,
            discountRatioLowerBound: _discountRatioLowerBound,
            volMultiplier: _volMultiplier
        });
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
     */
    function _addCollateral(
        Account memory _account,
        bytes memory _data,
        address subAccount
    ) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        // update the account structure in memory
        _account.addCollateral(amount, collateralId);

        address collateral = address(assets[collateralId].addr);

        // collateral must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, subAccount)) revert MA_InvalidFromAddress();
        IERC20(collateral).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     */
    function _removeCollateral(Account memory _account, bytes memory _data) internal {
        // decode parameters
        (uint80 amount, address recipient) = abi.decode(_data, (uint80, address));
        address collateral = address(assets[_account.collateralId].addr);

        // update the account structure in memory
        _account.removeCollateral(amount);

        // external calls
        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     */
    function _mintOption(Account memory _account, bytes memory _data) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account structure in memory
        _account.mintOption(tokenId, amount);

        // mint the real option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
     */
    function _burnOption(
        Account memory _account,
        bytes memory _data,
        address subAccount
    ) internal {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account structure in memory
        _account.burnOption(tokenId, amount);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, subAccount)) revert MA_InvalidFromAddress();
        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
     */
    function _merge(
        Account memory _account,
        bytes memory _data,
        address subAccount
    ) internal {
        // decode parameters
        (uint256 tokenId, address from) = abi.decode(_data, (uint256, address));

        // update the account structure in memory
        uint64 amount = _account.merge(tokenId);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, subAccount)) revert MA_InvalidFromAddress();

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     */
    function _split(Account memory _account, bytes memory _data) internal {
        // decode parameters
        (TokenType tokenType, address recipient) = abi.decode(_data, (TokenType, address));

        // update the account structure in memory
        (uint256 tokenId, uint64 amount) = _account.split(tokenType);

        optionToken.mint(recipient, tokenId, amount);
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
        if (_isPrimaryAccountFor(msg.sender, _subAccount)) return;

        // the sender is not the direct owner. check if he's authorized
        uint160 maskedAccountId = (uint160(_subAccount) | 0xFF);
        if (!authorized[maskedAccountId][msg.sender]) revert NoAccess();
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
        MarginAccountDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = _getMinCollateral(detail);
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param detail account memory dtail
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function _getMinCollateral(MarginAccountDetail memory detail) internal view returns (uint256 minCollateral) {
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
            productParams[detail.productId]
        );

        minCollateral = _convertDecimals(minCollateralInUnit, UNIT_DECIMALS, product.collateralDecimals);
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(Account memory account) internal pure returns (MarginAccountDetail memory detail) {
        detail = MarginAccountDetail({
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
        (address underlying, address strike, address collateral, uint8 collatDecimals) = getAssetsFromProductId(
            _productId
        );
        info.underlying = underlying;
        info.strike = strike;
        info.collateral = collateral;
        info.collateralDecimals = collatDecimals;
    }
}
