// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// libraries
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";

// // constants and types
import "../../../config/enums.sol";
import "../../../config/errors.sol";

/**
 * @title   DebitSpread
 * @author  @antoncoding, @dsshap
 * @notice  util functions for MarginEngines to support debit spreads
 */
abstract contract DebitSpread is BaseEngine {
    using TokenIdUtil for uint256;

    event OptionTokenMerged(address subAccount, uint256 longToken, uint256 shortToken, uint64 amount);

    event OptionTokenSplit(address subAccount, uint256 spreadId, uint64 amount);

    /**
     * ========================================================= **
     *                Internal Functions For Each Action
     * ========================================================= *
     */

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
     *         the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 longTokenId, uint256 shortTokenId, address from, uint64 amount) =
            abi.decode(_data, (uint256, uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert BM_InvalidFromAddress();

        _verifyMergeTokenIds(longTokenId, shortTokenId);

        // update the account in state
        _mergeLongIntoSpread(_subAccount, shortTokenId, longTokenId, amount);

        emit OptionTokenMerged(_subAccount, longTokenId, shortTokenId, amount);

        // this line will revert if user is trying to burn an un-authorized tokenId
        optionToken.burn(from, longTokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(address _subAccount, bytes calldata _data) internal virtual {
        // decode parameters
        (uint256 spreadId, uint64 amount, address recipient) = abi.decode(_data, (uint256, uint64, address));

        uint256 tokenId = _verifySpreadIdAndGetLong(spreadId);

        // update the account in state
        _splitSpreadInAccount(_subAccount, spreadId, amount);

        emit OptionTokenSplit(_subAccount, spreadId, amount);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * ========================================================= **
     *                State changing functions to override
     * ========================================================= *
     */

    function _mergeLongIntoSpread(address _subAccount, uint256 shortTokenId, uint256 longTokenId, uint64 amount)
        internal
        virtual
    {}

    function _splitSpreadInAccount(address _subAccount, uint256 spreadId, uint64 amount) internal virtual {}

    /**
     * ========================================================= **
     *             Internal Functions for tokenId verification
     * ========================================================= *
     */

    /**
     * @dev make sure the user can merge 2 tokens (1 long and 1 short) into a spread
     * @param longId id of the incoming token to be merged
     * @param shortId id of the existing short position
     */
    function _verifyMergeTokenIds(uint256 longId, uint256 shortId) internal pure {
        // get token attribute for incoming token
        (TokenType longType, uint40 productId, uint64 expiry, uint64 longStrike,) = longId.parseTokenId();

        // token being added can only be call or put
        if (longType != TokenType.CALL && longType != TokenType.PUT) revert BM_CannotMergeSpread();

        (TokenType shortType, uint40 productId_, uint64 expiry_, uint64 shortStrike,) = shortId.parseTokenId();

        // todo: use bit operation to compare these 3 fields
        // check that the merging token (long) has the same property as existing short
        if (shortType != longType) revert BM_MergeTypeMismatch();
        if (productId_ != productId) revert BM_MergeProductMismatch();
        if (expiry_ != expiry) revert BM_MergeExpiryMismatch();

        // should use burn instead
        if (longStrike == shortStrike) revert BM_MergeWithSameStrike();
    }

    function _verifySpreadIdAndGetLong(uint256 _spreadId) internal pure returns (uint256 longId) {
        // parse the passed in spread id
        (TokenType spreadType, uint40 productId, uint64 expiry,, uint64 shortStrike) = _spreadId.parseTokenId();

        if (spreadType != TokenType.CALL_SPREAD && spreadType != TokenType.PUT_SPREAD) revert BM_CanOnlySplitSpread();

        TokenType newType = spreadType == TokenType.CALL_SPREAD ? TokenType.CALL : TokenType.PUT;
        longId = TokenIdUtil.getTokenId(newType, productId, expiry, shortStrike, 0);
    }
}
