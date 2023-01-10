// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imported contracts and libraries
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {DebitSpread} from "../mixins/DebitSpread.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";

import {FullMarginMath} from "./FullMarginMath.sol";
import {FullMarginLib} from "./FullMarginLib.sol";

// constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// Full margin types
import "./types.sol";
import "./errors.sol";

/**
 * @title   FullMarginEngine
 * @author  @antoncoding
 * @notice  Fully collateralized margin engine
 *             Users can deposit collateral into FullMargin and mint optionTokens (debt) out of it.
 *             Interacts with OptionToken to mint / burn
 *             Interacts with grappa to fetch registered asset info
 */
contract FullMarginEngine is BaseEngine, DebitSpread, IMarginEngine, ReentrancyGuard {
    using FullMarginLib for FullMarginAccount;
    using FullMarginMath for FullMarginDetail;
    using TokenIdUtil for uint256;
    using SafeCast for uint256;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => FullMarginAccount structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => FullMarginAccount) public marginAccounts;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _grappa, address _optionToken) BaseEngine(_grappa, _optionToken) {}

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    function execute(address _subAccount, ActionArgs[] calldata actions) public override nonReentrant {
        _assertCallerHasAccess(_subAccount);

        // update the account state and do external calls on the flight
        for (uint256 i; i < actions.length;) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else revert FM_UnsupportedAction();

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
        if (!_isAccountAboveWater(_subAccount)) revert BM_AccountUnderwater();
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _recipient receiber
     * @param _amount amount
     */
    function payCashValue(address _asset, address _recipient, uint256 _amount) public override(BaseEngine, IMarginEngine) {
        BaseEngine.payCashValue(_asset, _recipient, _amount);
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        FullMarginDetail memory detail = _getAccountDetail(account);
        minCollateral = detail.getMinCollateral();
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();

        if (!marginAccounts[_newSubAccount].isEmpty()) revert FM_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = marginAccounts[_subAccount];

        delete marginAccounts[_subAccount];
    }

    /**
     * ========================================================= **
     *               Override Sate changing functions             *
     * ========================================================= **
     */

    function _addCollateralToAccount(address _subAccount, uint8 collateralId, uint80 amount) internal override {
        marginAccounts[_subAccount].addCollateral(collateralId, amount);
    }

    function _removeCollateralFromAccount(address _subAccount, uint8 collateralId, uint80 amount) internal override {
        marginAccounts[_subAccount].removeCollateral(collateralId, amount);
    }

    function _increaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        marginAccounts[_subAccount].mintOption(tokenId, amount);
    }

    function _decreaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        marginAccounts[_subAccount].burnOption(tokenId, amount);
    }

    function _mergeLongIntoSpread(address _subAccount, uint256 shortTokenId, uint256 longTokenId, uint64 amount)
        internal
        override
    {
        marginAccounts[_subAccount].merge(shortTokenId, longTokenId, amount);
    }

    function _splitSpreadInAccount(address _subAccount, uint256 spreadId, uint64 amount) internal override {
        marginAccounts[_subAccount].split(spreadId, amount);
    }

    function _settleAccount(address _subAccount, uint80 payout) internal override {
        marginAccounts[_subAccount].settleAtExpiry(payout);
    }

    /**
     * ========================================================= **
     *                 Override view functions for BaseEngine
     * ========================================================= *
     */

    /**
     * @dev return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view override returns (bool isHealthy) {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        uint256 minCollateral = _getMinCollateral(account);
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view override returns (uint8, uint80) {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        uint8 collatId = account.collateralId;
        (,, uint256 payout) = grappa.getPayout(account.tokenId, account.shortAmount);
        return (collatId, payout.toUint80());
    }

    /**
     * ========================================================= **
     *                         Internal Functions
     * ========================================================= *
     */

    function _getMinCollateral(FullMarginAccount memory account) internal view returns (uint256) {
        FullMarginDetail memory detail = _getAccountDetail(account);
        return detail.getMinCollateral();
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(FullMarginAccount memory account) internal view returns (FullMarginDetail memory detail) {
        (TokenType tokenType, uint40 productId,, uint64 longStrike, uint64 shortStrike) = account.tokenId.parseTokenId();

        (,,, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        bool collateralizedWithStrike = collateralId == strikeId;

        (, uint8 collateralDecimals) = grappa.assets(collateralId);

        detail = FullMarginDetail({
            shortAmount: account.shortAmount,
            longStrike: shortStrike,
            shortStrike: longStrike,
            collateralAmount: account.collateralAmount,
            collateralDecimals: collateralDecimals,
            collateralizedWithStrike: collateralizedWithStrike,
            tokenType: tokenType
        });
    }
}
