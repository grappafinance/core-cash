// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {MoneynessLib} from "../../../libraries/MoneynessLib.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";

// // constants and types
import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/errors.sol";

/**
 * @title   DebitSpread
 * @author  @antoncoding, @dsshap
 * @notice  util functions for MarginEngines to support debit spreads
 */
abstract contract DebitSpread is BaseEngine {
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using TokenIdUtil for uint256;

    event OptionTokenMerged(address subAccount, uint256 longToken, uint256 shortToken, uint64 amount);

    event OptionTokenSplit(address subAccount, uint256 spreadId, uint64 amount);

    /**
     * ========================================================= **
     *        External Functions for Token Cash Payout Calc
     * ========================================================= *
     */

    /**
     * @dev calculate the payout for one derivative token
     * @param _tokenId  token id of derivative token
     * @return payoutPerToken amount paid
     */
    function getCashSettlementPerToken(uint256 _tokenId)
        public
        view
        virtual
        override (BaseEngine)
        returns (uint256 payoutPerToken)
    {
        (DerivativeType derivativeType,, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) =
            TokenIdUtil.parseTokenId(_tokenId);

        (address oracle,, address underlying,, address strike,, address collateral, uint8 collateralDecimals) =
            grappa.getDetailFromProductId(productId);

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = _getSettlementPrice(oracle, underlying, strike, expiry);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;

        if (derivativeType == DerivativeType.CALL) {
            cashValue = MoneynessLib.getCallCashValue(expiryPrice, longStrike);
        } else if (derivativeType == DerivativeType.CALL_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitCallSpread(expiryPrice, longStrike, shortStrike);
        } else if (derivativeType == DerivativeType.PUT) {
            cashValue = MoneynessLib.getPutCashValue(expiryPrice, longStrike);
        } else if (derivativeType == DerivativeType.PUT_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitPutSpread(expiryPrice, longStrike, shortStrike);
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

        return (payoutPerToken);
    }

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

        // this line will revert if usre is trying to burn an un-authrized tokenId
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
        (DerivativeType longType, SettlementType settlementType, uint40 productId, uint64 expiry, uint64 longStrike,) =
            longId.parseTokenId();

        // token being added can only be call or put
        if (longType != DerivativeType.CALL && longType != DerivativeType.PUT) revert BM_CannotMergeSpread();

        (DerivativeType shortType, SettlementType settlementType_, uint40 productId_, uint64 expiry_, uint64 shortStrike,) =
            shortId.parseTokenId();

        // check that the merging token (long) has the same property as existing short
        if (shortType != longType) revert BM_MergeDerivativeTypeMismatch();
        if (settlementType != settlementType_) revert BM_MergeSettlementTypeMismatch();
        if (productId_ != productId) revert BM_MergeProductMismatch();
        if (expiry_ != expiry) revert BM_MergeExpiryMismatch();

        // should use burn instead
        if (longStrike == shortStrike) revert BM_MergeWithSameStrike();
    }

    function _verifySpreadIdAndGetLong(uint256 _spreadId) internal pure returns (uint256 longId) {
        // parse the passed in spread id
        (DerivativeType spreadType, SettlementType settlementType, uint40 productId, uint64 expiry,, uint64 shortStrike) =
            _spreadId.parseTokenId();

        if (spreadType != DerivativeType.CALL_SPREAD && spreadType != DerivativeType.PUT_SPREAD) revert BM_CanOnlySplitSpread();

        DerivativeType newType = spreadType == DerivativeType.CALL_SPREAD ? DerivativeType.CALL : DerivativeType.PUT;
        longId = TokenIdUtil.getTokenId(newType, settlementType, productId, expiry, shortStrike, 0);
    }
}
