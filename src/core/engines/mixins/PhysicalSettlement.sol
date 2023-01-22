// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {BalanceUtil} from "../../../libraries/BalanceUtil.sol";
import {IPhysicalSettlement} from "../../../interfaces/IPhysicalSettlement.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";

// // constants and types
import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * @title   PhysicalSettlement
 * @author  @dsshap
 * @notice  util functions for MarginEngines to support physically settled tokens
 */
abstract contract PhysicalSettlement is BaseEngine {
    using BalanceUtil for Balance[];
    using FixedPointMathLib for uint256;
    using SafeCast for uint256;

    /// @dev window to exercise physical token
    uint256 private _settlementWindow;

    /// @dev token => PhysicalSettlementTracker
    mapping(uint256 => PhysicalSettlementTracker) public tokenTracker;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    /*///////////////////////////////////////////////////////////////
                        Override Internal Functions
    //////////////////////////////////////////////////////////////*/

    function getBatchSettlementForShorts(uint256[] calldata _tokenIds, uint256[] calldata _amounts)
        external
        view
        returns (Balance[] memory debts, Balance[] memory payouts)
    {
        // payouts and debts will be 0 for physical settlement options because it has
        // passed the settlement window
        (debts, payouts) = grappa.getBatchSettlement(_tokenIds, _amounts);

        // add socialized physical settlement
        for (uint256 i; i < _tokenIds.length;) {
            PhysicalSettlementTracker memory tracker = tokenTracker[_tokenIds[i]];

            // if the token is physical settled and someone exercised prior to exercise window
            if (tracker.totalDebt > 0) {
                (Balance memory debt, Balance memory payout) = _socializeSettlement(tracker, _tokenIds[i], _amounts[i]);
                debts = _addToBalances(debts, debt.collateralId, debt.amount);
                payouts = _addToBalances(payouts, payout.collateralId, payout.amount);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _socializeSettlement(PhysicalSettlementTracker memory tracker, uint256 tokenId, uint256 shortAmount)
        internal
        pure
        returns (Balance memory debt, Balance memory payout)
    {
        (TokenType tokenType,, uint40 productId,,,) = TokenIdUtil.parseTokenId(tokenId);
        (,, uint8 underlyingId, uint8 strikeId,) = ProductIdUtil.parseProductId(productId);

        if (tokenType == TokenType.CALL) {
            debt.collateralId = strikeId;
            payout.collateralId = underlyingId;
        } else if (tokenType == TokenType.PUT) {
            debt.collateralId = underlyingId;
            payout.collateralId = strikeId;
        }
        debt.amount = (tracker.totalDebt * shortAmount / tracker.issued).toUint80();
        payout.amount = (tracker.totalCollateralPaid * shortAmount / tracker.issued).toUint80();
    }

    function handleExercise(
        uint256 _tokenId,
        uint256, /*_tokenExercised*/
        address _inAsset,
        uint256 _inAmount,
        address _from,
        address _outAsset,
        uint256 _outAmount,
        address _to
    ) external {
        // tokenTracker[_tokenId].exercised += _tokenExercised.toUint64();
        tokenTracker[_tokenId].totalDebt += _inAmount;
        tokenTracker[_tokenId].totalCollateralPaid += _outAmount;

        _receiveDebtValue(_inAsset, _from, _inAmount);

        _sendPayoutValue(_outAsset, _to, _outAmount);
    }

    /**
     * @dev mint option token to _subAccount, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOption(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        tokenTracker[tokenId].issued += amount;
    }

    /**
     * @dev mint option token into account, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOptionIntoAccount(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // grappa.trackTokenIssuance(tokenId, amount, true);
        tokenTracker[tokenId].issued += amount;
    }

    /**
     * @dev burn option token from user, decrease tracker issuance
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._burnOption(_subAccount, _data);

        // decode parameters
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        tokenTracker[tokenId].issued -= amount;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev set new settlement window
     * @param _window is the time from expiry that the option can be exercised
     */
    function _setSettlementWindow(uint256 _window) internal virtual {
        if (_window < MIN_SETTLEMENT_WINDOW) revert PS_InvalidSettlementWindow();

        _settlementWindow = _window;
    }

    /**
     * @dev gets current settlement window
     */
    function _getSettlementWindow() internal view returns (uint256) {
        return _settlementWindow != 0 ? _settlementWindow : MIN_SETTLEMENT_WINDOW;
    }

    /**
     * @dev add an entry to array of Balance
     * @param balances existing payout array
     * @param _asset new collateralId
     * @param _amount new payout
     */
    function _addToBalances(Balance[] memory balances, uint8 _asset, uint256 _amount)
        internal
        pure
        returns (Balance[] memory newBalances)
    {
        (bool found, uint256 index) = balances.indexOf(_asset);

        uint80 balance = _amount.toUint80();

        if (!found) balances = balances.append(Balance(_asset, balance));
        else balances[index].amount += balance;

        return balances;
    }
}
