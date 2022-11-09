// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {AccountUtil} from "../../../libraries/AccountUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

import {FullMarginMathV2} from "./FullMarginMathV2.sol";
import {FullMarginLibV2} from "./FullMarginLibV2.sol";

// constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title   FullMarginEngineV2
 * @author  @dsshap, @antoncoding
 * @notice  Fully collateralized margin engine
            Users can deposit collateral into FullMargin and mint optionTokens (debt) out of it.
            Interacts with OptionToken to mint / burn
            Interacts with grappa to fetch registered asset info
 */
contract FullMarginEngineV2 is BaseEngine, IMarginEngine {
    using ArrayUtil for bytes32[];
    using ArrayUtil for int256[];
    using ArrayUtil for uint256[];

    using AccountUtil for Balance[];
    using AccountUtil for FullMarginDetailV2[];
    using AccountUtil for Position[];
    using AccountUtil for PositionOptim[];
    using AccountUtil for SBalance[];

    using FullMarginLibV2 for FullMarginAccountV2;
    using FullMarginMathV2 for FullMarginDetailV2;
    using SafeCast for uint256;
    using SafeCast for int256;
    using TokenIdUtil for uint256;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => FullMarginAccountV2 structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => FullMarginAccountV2) internal accounts;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _grappa, address _optionToken) BaseEngine(_grappa, _optionToken) {}

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    function batchExecute(BatchExecute[] calldata batchActions) public nonReentrant {
        uint256 i;
        for (i; i < batchActions.length; ) {
            address subAccount = batchActions[i].subAccount;
            ActionArgs[] calldata actions = batchActions[i].actions;

            _execute(subAccount, actions);

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }

        for (i = 0; i < batchActions.length; ) {
            if (!_isAccountAboveWater(batchActions[i].subAccount)) revert BM_AccountUnderwater();

            unchecked {
                ++i;
            }
        }
    }

    function execute(address _subAccount, ActionArgs[] calldata actions) public override nonReentrant {
        _execute(_subAccount, actions);

        if (!_isAccountAboveWater(_subAccount)) revert BM_AccountUnderwater();
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
    ) public override(BaseEngine, IMarginEngine) {
        BaseEngine.payCashValue(_asset, _recipient, _amount);
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return balances array of collaterals and amount (signed)
     */
    function getMinCollateral(address _subAccount) external view returns (SBalance[] memory balances) {
        FullMarginAccountV2 memory account = accounts[_subAccount];
        balances = _getMinCollateral(account);
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();

        if (!accounts[_newSubAccount].isEmpty()) revert FM_AccountIsNotEmpty();
        accounts[_newSubAccount] = accounts[_subAccount];

        delete accounts[_subAccount];
    }

    function marginAccounts(address _subAccount)
        external
        view
        returns (
            Position[] memory shorts,
            Position[] memory longs,
            Balance[] memory collaterals
        )
    {
        FullMarginAccountV2 memory account = accounts[_subAccount];

        return (account.shorts.getPositions(), account.longs.getPositions(), account.collaterals);
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param shorts positions.
     * @param longs positions.
     * @return balances array of collaterals and amount
     */
    function previewMinCollateral(Position[] memory shorts, Position[] memory longs)
        external
        view
        returns (Balance[] memory balances)
    {

        FullMarginAccountV2 memory account;

        account.shorts = shorts.getPositionOptims();
        account.longs = longs.getPositionOptims();

        balances = _getMinCollateral(account).toBalances();
    }

    /** ========================================================= **
                   Override Internal Functions For Each Action
     ** ========================================================= **/

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     */
    function _settle(address _subAccount) internal override {
        // update the account in state
        (, Balance[] memory shortPayouts) = _settleAccount2(_subAccount);
        emit AccountSettled2(_subAccount, shortPayouts);
    }

    /** ========================================================= **
     *               Override Sate changing functions             *
     ** ========================================================= **/

    function _addCollateralToAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {
        accounts[_subAccount].addCollateral(collateralId, amount);
    }

    function _removeCollateralFromAccount(
        address _subAccount,
        uint8 collateralId,
        uint80 amount
    ) internal override {
        accounts[_subAccount].removeCollateral(collateralId, amount);
    }

    function _increaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        accounts[_subAccount].mintOption(tokenId, amount);
    }

    function _decreaseShortInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        accounts[_subAccount].burnOption(tokenId, amount);
    }

    function _increaseLongInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        accounts[_subAccount].addOption(tokenId, amount);
    }

    function _decreaseLongInAccount(
        address _subAccount,
        uint256 tokenId,
        uint64 amount
    ) internal override {
        accounts[_subAccount].removeOption(tokenId, amount);
    }

    function _settleAccount2(address _subAccount)
        internal
        returns (Balance[] memory longPayouts, Balance[] memory shortPayouts)
    {
        (longPayouts, shortPayouts) = accounts[_subAccount].settleAtExpiry(grappa);
    }

    /** ========================================================= **
                    Override view functions for BaseEngine
     ** ========================================================= **/

    /**
     * @dev return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view override returns (bool isHealthy) {
        FullMarginAccountV2 memory account = accounts[_subAccount];
        SBalance[] memory balances = _getMinCollateral(account);

        for (uint256 i; i < balances.length; ) {
            if (balances[i].amount < 0) return false;

            unchecked {
                ++i;
            }
        }

        return true;
    }

    // handling this in MarginLib
    // solhint-disable-next-line no-empty-blocks
    function _getAccountPayout(address _subAccount) internal view override returns (uint80) {}

    /**
     * @dev reverts if the account cannot add this token into the margin account.
     * @param tokenId tokenId
     */
    function _verifyLongTokenIdToAdd(uint256 tokenId) internal view override {
        (TokenType optionType, uint40 productId, uint64 expiry, , ) = tokenId.parseTokenId();

        // engine only supports calls and puts
        if (optionType != TokenType.CALL && optionType != TokenType.PUT) revert FM_UnsupportedTokenType();

        if (block.timestamp > expiry) revert FM_Option_Expired();

        ProductDetails memory product = _getProductDetails(productId);

        // in the future reference a whitelist of engines
        if (product.engine != address(this)) revert FM_Not_Authorized_Engine();
    }

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

    function _execute(address _subAccount, ActionArgs[] calldata actions) internal {
        _assertCallerHasAccess(_subAccount);

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShortIntoAccount)
                _mintOptionIntoAccount(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.TransferLong) _transferLong(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.TransferShort) _transferShort(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.TransferCollateral)
                _transferCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.AddLong) _addOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveLong) _removeOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else revert FM_UnsupportedAction();

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
    }

    function _getMinCollateral(FullMarginAccountV2 memory account) internal view returns (SBalance[] memory balances) {
        FullMarginDetailV2[] memory details = _getAccountDetails(account);

        balances = account.collaterals.toSBalances();

        if (details.length == 0) return balances;

        bool found;
        uint256 index;

        for (uint256 i; i < details.length; ) {
            FullMarginDetailV2 memory detail = details[i];
            if(detail.callWeights.length != 0 || detail.putWeights.length != 0) {
                (int256 cashCollateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();

                if (cashCollateralNeeded != 0) {
                    (found, index) = balances.indexOf(detail.collateralId);
                    if (found) balances[index].amount -= cashCollateralNeeded.toInt80();
                    else balances = balances.append(SBalance(detail.collateralId, -cashCollateralNeeded.toInt80()));
                }

                if (underlyingNeeded != 0) {
                    (found, index) = balances.indexOf(detail.underlyingId);
                    if (found) balances[index].amount -= underlyingNeeded.toInt80();
                    else balances = balances.append(SBalance(detail.underlyingId, -underlyingNeeded.toInt80()));
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetails(FullMarginAccountV2 memory account)
        internal
        view
        returns (FullMarginDetailV2[] memory details)
    {
        details = new FullMarginDetailV2[](0);

        bytes32[] memory usceLookUp = new bytes32[](0);

        Position[] memory positions = account.shorts.getPositions().concat(account.longs.getPositions());
        uint256 shortLength = account.shorts.length;

        for (uint256 i; i < positions.length; ) {
            (, uint40 productId, uint64 expiry, , ) = positions[i].tokenId.parseTokenId();

            ProductDetails memory product = _getProductDetails(productId);

            bytes32 pos = keccak256(abi.encode(product.underlyingId, product.strikeId, product.collateralId, expiry));
            (bool found, uint256 index) = usceLookUp.indexOf(pos);

            FullMarginDetailV2 memory detail;

            if (found) detail = details[index];
            else {
                usceLookUp = usceLookUp.append(pos);
                details = details.append(detail);

                detail.underlyingId = product.underlyingId;
                detail.underlyingDecimals = product.underlyingDecimals;
                detail.collateralId = product.collateralId;
                detail.collateralDecimals = product.collateralDecimals;
                detail.spotPrice = IOracle(product.oracle).getSpotPrice(product.underlying, product.strike);
                detail.expiry = expiry;
            }

            int256 amount = int256(int64(positions[i].amount));
            if (i < shortLength) amount = -amount;
            _processDetailWithToken(detail, positions[i].tokenId, amount);

            unchecked {
                ++i;
            }
        }
    }

    function _processDetailWithToken(
        FullMarginDetailV2 memory detail,
        uint256 tokenId,
        int256 amount
    ) internal pure {
        (TokenType tokenType, , , uint64 longStrike, ) = tokenId.parseTokenId();

        bool found;
        uint256 index;

        if (tokenType == TokenType.CALL) {
            (found, index) = detail.callStrikes.indexOf(longStrike);
            if (found) {
                detail.callWeights[index] += amount;
                if(detail.callWeights[index] == 0) {
                    detail.callWeights = detail.callWeights.remove(index);
                    detail.callStrikes = detail.callStrikes.remove(index);
                }
            }
            else {
                detail.callStrikes = detail.callStrikes.append(longStrike);
                detail.callWeights = detail.callWeights.append(amount);
            }
        }

        if (tokenType == TokenType.PUT) {
            (found, index) = detail.putStrikes.indexOf(longStrike);
            if (found) {
                detail.putWeights[index] += amount;
                if(detail.putWeights[index] == 0) {
                    detail.putWeights = detail.putWeights.remove(index);
                    detail.putStrikes = detail.putStrikes.remove(index);
                }
            }
            else {
                detail.putStrikes = detail.putStrikes.append(longStrike);
                detail.putWeights = detail.putWeights.append(amount);
            }
        }
    }

    function _getProductDetails(uint40 productId) internal view returns (ProductDetails memory info) {
        (, , uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        (
            address oracle,
            address engine,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            uint8 strikeDecimals,
            address collateral,
            uint8 collatDecimals
        ) = grappa.getDetailFromProductId(productId);

        info.oracle = oracle;
        info.engine = engine;
        info.underlying = underlying;
        info.underlyingId = underlyingId;
        info.underlyingDecimals = underlyingDecimals;
        info.strike = strike;
        info.strikeId = strikeId;
        info.strikeDecimals = strikeDecimals;
        info.collateral = collateral;
        info.collateralId = collateralId;
        info.collateralDecimals = collatDecimals;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
