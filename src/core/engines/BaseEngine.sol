// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable no-empty-blocks

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

// interfaces
import {IGrappa} from "../../interfaces/IGrappa.sol";
import {IOptionToken} from "../../interfaces/IOptionToken.sol";
import {IOracle} from "../../interfaces/IOracle.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// librarise
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";
import {MoneynessLib} from "../../libraries/MoneynessLib.sol";
import {NumberUtil} from "../../libraries/NumberUtil.sol";

// constants and types
import "../../config/types.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";

/**
 * @title   MarginBase
 * @author  @antoncoding, @dsshap
 * @notice  util functions for MarginEngines
 */
abstract contract BaseEngine {
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using SafeERC20 for IERC20;
    using TokenIdUtil for uint256;

    IGrappa public immutable grappa;
    IOptionToken public immutable optionToken;

    ///@dev maskedAccount => operator => allowedExecutionLeft
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    ///     allowedExecutionLeft referres to the time left the grantee can update the sub-accounts.
    mapping(uint160 => mapping(address => uint256)) public allowedExecutionLeft;

    /// Events
    event AccountAuthorizationUpdate(uint160 maskId, address account, uint256 updatesAllowed);

    event CollateralAdded(address subAccount, address collateral, uint256 amount);

    event CollateralRemoved(address subAccount, address collateral, uint256 amount);

    event CollateralTransfered(address from, address to, uint8 collateralId, uint256 amount);

    event OptionTokenMinted(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenAdded(address subAccount, uint256 tokenId, uint64 amount);

    event OptionTokenRemoved(address subAccount, uint256 tokenId, uint64 amount);

    event OptionTokenTransfered(address from, address to, uint256 tokenId, uint64 amount);

    event AccountSettled(address subAccount, Balance[] debts, Balance[] payouts);

    /**
     * ========================================================= **
     *                         External Functions
     * ========================================================= *
     */

    constructor(address _grappa, address _optionToken) {
        grappa = IGrappa(_grappa);
        optionToken = IOptionToken(_optionToken);
    }

    /**
     * ========================================================= **
     *                         External Functions
     * ========================================================= *
     */

    /**
     * @notice  grant or revoke an account access to all your sub-accounts
     * @dev     expected to be call by account owner
     *          usually user should only give access to helper contracts
     * @param   _account account to update authorization
     * @param   _allowedExecutions how many times the account is authrized to update your accounts.
     *          set to max(uint256) to allow premanent access
     */
    function setAccountAccess(address _account, uint256 _allowedExecutions) external {
        uint160 maskedId = uint160(msg.sender) | 0xFF;
        allowedExecutionLeft[maskedId][_account] = _allowedExecutions;

        emit AccountAuthorizationUpdate(maskedId, _account, _allowedExecutions);
    }

    /**
     * @dev resolve access granted to yourself
     * @param _granter address that granted you access
     */
    function revokeSelfAccess(address _granter) external {
        uint160 maskedId = uint160(_granter) | 0xFF;
        allowedExecutionLeft[maskedId][msg.sender] = 0;

        emit AccountAuthorizationUpdate(maskedId, msg.sender, 0);
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _recipient receiver
     * @param _amount amount
     */
    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) public virtual {
        _checkIsGrappa();

        if (_recipient != address(this)) IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    /**
     * @dev calculate the cash settled payout for one option token
     * @param _tokenId  token id of option token
     * @return payoutPerToken amount paid
     */
    function getCashSettlementPerToken(uint256 _tokenId) public view virtual returns (uint256 payoutPerToken) {
        (TokenType tokenType, SettlementType settlementType, uint40 productId, uint64 expiry, uint64 strikePrice,) =
            TokenIdUtil.parseTokenId(_tokenId);

        if (settlementType == SettlementType.PHYSICAL) revert BM_InvalidSettlementType();

        (address oracle,, address underlying,, address strike,, address collateral, uint8 collateralDecimals) =
            grappa.getDetailFromProductId(productId);

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = _getSettlementPrice(oracle, underlying, strike, expiry);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;

        if (tokenType == TokenType.CALL) {
            cashValue = MoneynessLib.getCallCashValue(expiryPrice, strikePrice);
        } else if (tokenType == TokenType.PUT) {
            cashValue = MoneynessLib.getPutCashValue(expiryPrice, strikePrice);
        }

        // the following logic convert cash value (amount worth) if collateral is not strike:
        if (collateral == underlying) {
            // collateral is underlying. payout should be devided by underlying price
            cashValue = cashValue.mulDivDown(UNIT, expiryPrice);
        } else if (collateral != strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = _getSettlementPrice(oracle, collateral, strike, expiry);
            cashValue = cashValue.mulDivDown(UNIT, collateralPrice);
        }

        payoutPerToken = cashValue.convertDecimals(UNIT_DECIMALS, collateralDecimals);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * ========================================================= **
     *                Internal Functions For Each Action
     * ========================================================= *
     */

    /**
     * @dev pull token from user, increase collateral in account storage
     *         the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _addCollateralToAccount(_subAccount, collateralId, amount);

        (address collateral,) = grappa.assets(collateralId);

        emit CollateralAdded(_subAccount, collateral, amount);

        IERC20(collateral).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @dev push token to user, decrease collateral in storage
     * @param _data bytes data to decode
     */
    function _removeCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in state
        _removeCollateralFromAccount(_subAccount, collateralId, amount);

        (address collateral,) = grappa.assets(collateralId);

        emit CollateralRemoved(_subAccount, collateral, amount);

        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in storage
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _increaseShortInAccount(_subAccount, tokenId, amount);

        emit OptionTokenMinted(_subAccount, tokenId, amount);

        // mint option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev mint option token into account, increase short position (debt) and increase long position in storage
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address recipientSubAccount, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _increaseShortInAccount(_subAccount, tokenId, amount);

        emit OptionTokenMinted(_subAccount, tokenId, amount);

        _verifyLongTokenIdToAdd(tokenId);

        // update the account in state
        _increaseLongInAccount(recipientSubAccount, tokenId, amount);

        emit OptionTokenAdded(recipientSubAccount, tokenId, amount);

        // mint option token
        optionToken.mint(address(this), tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in storage
     *         the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _decreaseShortInAccount(_subAccount, tokenId, amount);

        emit OptionTokenBurned(_subAccount, tokenId, amount);

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev Add long token into the account to reduce capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _addOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, uint64 amount, address from) = abi.decode(_data, (uint256, uint64, address));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        _verifyLongTokenIdToAdd(tokenId);

        // update the state
        _increaseLongInAccount(_subAccount, tokenId, amount);

        emit OptionTokenAdded(_subAccount, tokenId, amount);

        // transfer the option token in
        IERC1155(address(optionToken)).safeTransferFrom(from, address(this), tokenId, amount, "");
    }

    /**
     * @dev Remove long token from the account to increase capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _removeOption(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, uint64 amount, address to) = abi.decode(_data, (uint256, uint64, address));

        // update the state
        _decreaseLongInAccount(_subAccount, tokenId, amount);

        emit OptionTokenRemoved(_subAccount, tokenId, amount);

        // transfer the option token in
        IERC1155(address(optionToken)).safeTransferFrom(address(this), to, tokenId, amount, "");
    }

    /**
     * @dev Transfers collateral to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferCollateral(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint80 amount, address to, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in state
        _removeCollateralFromAccount(_subAccount, collateralId, amount);
        _addCollateralToAccount(to, collateralId, amount);

        emit CollateralTransfered(_subAccount, to, collateralId, amount);
    }

    /**
     * @dev Transfers short tokens to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferShort(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address to, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        _assertCallerHasAccess(to);

        // update the account in state
        _decreaseShortInAccount(_subAccount, tokenId, amount);
        _increaseShortInAccount(to, tokenId, amount);

        emit OptionTokenTransfered(_subAccount, to, tokenId, amount);

        if (!_isAccountAboveWater(to)) revert BM_AccountUnderwater();
    }

    /**
     * @dev Transfers long tokens to another account.
     * @param _subAccount subaccount that will be update in place
     */
    function _transferLong(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 tokenId, address to, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _decreaseLongInAccount(_subAccount, tokenId, amount);
        _increaseLongInAccount(to, tokenId, amount);

        emit OptionTokenTransfered(_subAccount, to, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account storage
     */
    function _settle(address _subAccount) internal virtual {
        (uint8 collateralId, uint80 payout) = _getAccountPayout(_subAccount);

        // update the account in state
        _settleAccount(_subAccount, payout);

        Balance[] memory payouts = new Balance[](1);
        payouts[0] = Balance(collateralId, payout);

        emit AccountSettled(_subAccount, new Balance[](0), payouts);
    }

    /**
     * ========================================================= **
     *                State changing functions to override
     * ========================================================= *
     */
    function _addCollateralToAccount(address _subAccount, uint8 collateralId, uint80 amount) internal virtual {}

    function _removeCollateralFromAccount(address _subAccount, uint8 collateralId, uint80 amount) internal virtual {}

    function _increaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _decreaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _increaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _decreaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal virtual {}

    function _settleAccount(address _subAccount, uint80 payout) internal virtual {}

    /**
     * ========================================================= **
     *                View functions to override
     * ========================================================= *
     */

    /**
     * @notice [MUST Implement] return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view virtual returns (uint8 collateralId, uint80 payout);

    /**
     * @dev [MUST Implement] return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view virtual returns (bool);

    /**
     * @dev reverts if the account cannot add this token into the margin account.
     * @param tokenId tokenId
     */
    function _verifyLongTokenIdToAdd(uint256 tokenId) internal view virtual {}

    /**
     * ========================================================= **
     *                Internal view functions
     * ========================================================= *
     */

    /**
     * @notice revert if the msg.sender is not authorized to access an subAccount id
     * @param _subAccount subaccount id
     */
    function _assertCallerHasAccess(address _subAccount) internal {
        if (_isPrimaryAccountFor(msg.sender, _subAccount)) return;

        // the sender is not the direct owner. check if they're authorized
        uint160 maskedAccountId = (uint160(_subAccount) | 0xFF);

        uint256 allowance = allowedExecutionLeft[maskedAccountId][msg.sender];
        if (allowance == 0) revert NoAccess();

        // if allowance is not set to max uint256, reduce the number
        if (allowance != type(uint256).max) allowedExecutionLeft[maskedAccountId][msg.sender] = allowance - 1;
    }

    /**
     * @notice return if {_primary} address is the primary account for {_subAccount}
     */
    function _isPrimaryAccountFor(address _primary, address _subAccount) internal pure returns (bool) {
        return (uint160(_primary) | 0xFF) == (uint160(_subAccount) | 0xFF);
    }

    /**
     * @dev check settlement price is finalized from oracle, and return price
     * @param _oracle oracle contract address
     * @param _base base asset (ETH is base asset while requesting ETH / USD)
     * @param _quote quote asset (USD is base asset while requesting ETH / USD)
     * @param _expiry expiry timestamp
     */
    function _getSettlementPrice(address _oracle, address _base, address _quote, uint256 _expiry)
        internal
        view
        returns (uint256)
    {
        (uint256 price, bool isFinalized) = IOracle(_oracle).getPriceAtExpiry(_base, _quote, _expiry);
        if (!isFinalized) revert GP_PriceNotFinalized();
        return price;
    }

    /**
     * @dev check if msg.sender is the marginAccount
     */
    function _checkIsGrappa() internal view {
        if (msg.sender != address(grappa)) revert NoAccess();
    }
}
