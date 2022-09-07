// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// solhint-disable no-empty-blocks

// imported contracts and libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// interfaces
import {IGrappa} from "../../interfaces/IGrappa.sol";
import {IOptionToken} from "../../interfaces/IOptionToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// librarise
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

// constants and types
import "../../config/types.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";

/**
 * @title   MarginBase
 * @author  @antoncoding
 * @notice  util functions for MarginEngines
 */
abstract contract BaseEngine is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using TokenIdUtil for uint256;

    IGrappa public immutable grappa;
    IOptionToken public immutable optionToken;

    ///@dev maskedAccount => operator => authorized
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    mapping(uint160 => mapping(address => bool)) public authorized;

    /// Events
    event AccountAuthorizationUpdate(uint160 maskId, address account, bool isAuth);

    event CollateralAdded(address subAccount, address collateral, uint256 amount);

    event CollateralRemoved(address subAccount, address collateral, uint256 amount);

    event OptionTokenMinted(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenMerged(address subAccount, uint256 longToken, uint256 shortToken, uint64 amount);

    event OptionTokenSplit(address subAccount, uint256 spreadId, uint64 amount);

    event OptionTokenAdded(address subAccount, uint256 tokenId, uint64 amount);

    event OptionTokenRemoved(address subAccount, uint256 tokenId, uint64 amount);

    event AccountSettled(address subAccount, uint256 payout);

    /** ========================================================= **
                            External Functions
     ** ========================================================= **/

    constructor(address _grappa, address _optionToken) {
        grappa = IGrappa(_grappa);
        optionToken = IOptionToken(_optionToken);
    }

    /** ========================================================= **
                            External Functions
     ** ========================================================= **/

    /**
     * @notice  grant or revoke an account access to all your sub-accounts
     * @dev     expected to be call by account owner
     *          usually user should only give access to helper contracts
     * @param   _account account to update authorization
     * @param   _isAuthorized to grant or revoke access
     */
    function setAccountAccess(address _account, bool _isAuthorized) external {
        uint160 maskedId = uint160(msg.sender) | 0xFF;
        authorized[maskedId][_account] = _isAuthorized;

        emit AccountAuthorizationUpdate(maskedId, _account, _isAuthorized);
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _recipient receiber
     * @param _amount amount
     */
    function payCashValue(
        address _asset,
        address _recipient,
        uint256 _amount
    ) public virtual {
        if (msg.sender != address(grappa)) revert NoAccess();
        IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    /** ========================================================= **
                   Internal Functions For Each Action
     ** ========================================================= **/

    /**
     * @dev pull token from user, increase collateral in account memory
            the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        // update the account in state
        _addCollateralToAccount(_subAccount, collateralId, amount);

        address collateral = grappa.assets(collateralId).addr;

        emit CollateralAdded(_subAccount, collateral, amount);

        IERC20(collateral).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     * @param _data bytes data to decode
     */
    function _removeCollateral(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in state
        _removeCollateralFromAccount(_subAccount, collateralId, amount);

        address collateral = grappa.assets(collateralId).addr;

        emit CollateralRemoved(_subAccount, collateral, amount);

        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account in state
        _increaseShortInAccount(_subAccount, tokenId, amount);

        emit OptionTokenMinted(_subAccount, tokenId, amount);

        // mint option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes memory _data) internal {
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
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint256 longTokenId, uint256 shortTokenId, address from, uint64 amount) = abi.decode(
            _data,
            (uint256, uint256, address, uint64)
        );

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        _verifyMergeTokenIds(longTokenId, shortTokenId);

        // update the account in state
        _mergeLongIntoSpread(_subAccount, shortTokenId, longTokenId, amount);

        emit OptionTokenMerged(_subAccount, longTokenId, shortTokenId, amount);

        // this line will revert if usre is trying to burn an un-authrized tokenId
        optionToken.burn(from, longTokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint256 spreadId, uint64 amount, address recipient) = abi.decode(_data, (uint256, uint64, address));

        uint256 tokenId = _verifySpreadIdAndGetLong(spreadId);

        // update the account in state
        _splitSpreadInAccount(_subAccount, spreadId, amount);

        emit OptionTokenSplit(_subAccount, spreadId, amount);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev Add long token into the account to reduce capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _addOption(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint256 tokenId, uint64 amount, address from) = abi.decode(_data, (uint256, uint64, address));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        _verifyLongTokenIdToAdd(tokenId);

        // update the state
        _addOptionToAccount(_subAccount, tokenId, amount);

        emit OptionTokenAdded(_subAccount, tokenId, amount);

        // transfer the option token in
        IERC1155(address(optionToken)).safeTransferFrom(from, address(this), tokenId, amount, "");
    }

    /**
     * @dev Add long token into the account to reduce capital requirement.
     * @param _subAccount subaccount that will be update in place
     */
    function _removeOption(address _subAccount, bytes memory _data) internal {
        // decode parameters
        (uint256 tokenId, uint64 amount, address to) = abi.decode(_data, (uint256, uint64, address));

        // update the state
        _removeOptionfromAccount(_subAccount, tokenId, amount);

        emit OptionTokenRemoved(_subAccount, tokenId, amount);

        // transfer the option token in
        IERC1155(address(optionToken)).safeTransferFrom(address(this), to, tokenId, amount, "");
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     */
    function _settle(address _subAccount) internal {
        uint80 payout = _getAccountPayout(_subAccount);

        // update the account in state
        _settleAccount(_subAccount, payout);

        emit AccountSettled(_subAccount, payout);
    }

    /** ========================================================= **
                   State changing functions to override
     ** ========================================================= **/
    function _addCollateralToAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal virtual {}

    function _removeCollateralFromAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal virtual {}

    function _increaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal virtual {}

    function _decreaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal virtual {}

    function _mergeLongIntoSpread(
        address _subAccount,
        uint256 shortTokenId,
        uint256 longTokenId,
        uint64 amount
    ) internal virtual {}

    function _splitSpreadInAccount(
        address _subAccount,
        uint256 spreadId,
        uint64 amount
    ) internal virtual {}

    function _addOptionToAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal virtual {}

    function _removeOptionfromAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal virtual {}

    function _settleAccount(address _subAccount, uint80 payout) internal virtual {}

    /** ========================================================= **
                   View functions to override
     ** ========================================================= **/

    /**
     * @notice [MUST Implement] return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view virtual returns (uint80);

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

    /** ========================================================= **
                   Internal view functions 
     ** ========================================================= **/

    /**
     * @notice revert if the msg.sender is not authorized to access an subAccount id
     * @param _subAccount subaccount id
     */
    function _assertCallerHasAccess(address _subAccount) internal view {
        if (_isPrimaryAccountFor(msg.sender, _subAccount)) return;

        // the sender is not the direct owner. check if he's authorized
        uint160 maskedAccountId = (uint160(_subAccount) | 0xFF);
        if (!authorized[maskedAccountId][msg.sender]) revert NoAccess();
    }

    /**
     * @notice return if {_primary} address is the primary account for {_subAccount}
     */
    function _isPrimaryAccountFor(address _primary, address _subAccount) internal pure returns (bool) {
        return (uint160(_primary) | 0xFF) == (uint160(_subAccount) | 0xFF);
    }

    /** ========================================================= **
                Internal Functions for tokenId verification
     ** ========================================================= **/

    /**
     * @dev make sure the user can merge 2 tokens (1 long and 1 short) into a spread
     * @param longId id of the incoming token to be merged
     * @param shortId id of the existing short position
     */
    function _verifyMergeTokenIds(uint256 longId, uint256 shortId) internal pure {
        // get token attribute for incoming token
        (TokenType longType, uint32 productId, uint64 expiry, uint64 longStrike, ) = longId.parseTokenId();

        // token being added can only be call or put
        if (longType != TokenType.CALL && longType != TokenType.PUT) revert BM_CannotMergeSpread();

        (TokenType shortType, uint32 productId_, uint64 expiry_, uint64 shortStrike, ) = shortId.parseTokenId();

        // check that the merging token (long) has the same property as existing short
        if (shortType != longType) revert BM_MergeTypeMismatch();
        if (productId_ != productId) revert BM_MergeProductMismatch();
        if (expiry_ != expiry) revert BM_MergeExpiryMismatch();

        // should use burn instead
        if (longStrike == shortStrike) revert BM_MergeWithSameStrike();
    }

    function _verifySpreadIdAndGetLong(uint256 _spreadId) internal pure returns (uint256 longId) {
        // parse the passed in spread id
        (TokenType spreadType, uint32 productId, uint64 expiry, , uint64 shortStrike) = _spreadId.parseTokenId();

        if (spreadType != TokenType.CALL_SPREAD && spreadType != TokenType.PUT_SPREAD) revert BM_CanOnlySplitSpread();

        TokenType newType = spreadType == TokenType.CALL_SPREAD ? TokenType.CALL : TokenType.PUT;
        longId = TokenIdUtil.formatTokenId(newType, productId, expiry, shortStrike, 0);
    }
}
