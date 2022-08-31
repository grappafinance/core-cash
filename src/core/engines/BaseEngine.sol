// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// interfaces
import {IGrappa} from "../../interfaces/IGrappa.sol";
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
contract BaseEngine {
    using SafeERC20 for IERC20;
    using TokenIdUtil for uint256;

    IGrappa public immutable grappa;

    ///@dev maskedAccount => operator => authorized
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    mapping(uint160 => mapping(address => bool)) public authorized;

    /// Events
    event AccountAuthorizationUpdate(uint160 maskId, address account, bool isAuth);

    constructor(address _grappa) {
        grappa = IGrappa(_grappa);
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
                   Internal Functions For Access Control
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
