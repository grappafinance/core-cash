// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// imported contracts and libraries
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {PhysicalSettlement} from "../mixins/PhysicalSettlement.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";
import {IPhysicalSettlement} from "../../../interfaces/IPhysicalSettlement.sol";
import {IWhitelist} from "../../../interfaces/IWhitelist.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {BalanceUtil} from "../../../libraries/BalanceUtil.sol";
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

// Cross margin libraries
import {AccountUtil} from "./AccountUtil.sol";
import {CrossMarginMath} from "./CrossMarginMath.sol";
import {CrossMarginLib} from "./CrossMarginLib.sol";

// Cross margin types
import "./types.sol";

// global constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title   CrossMarginEngine
 * @author  @dsshap, @antoncoding
 * @notice  Fully collateralized margin engine
 *             Users can deposit collateral into Cross Margin and mint optionTokens (debt) out of it.
 *             Interacts with OptionToken to mint / burn
 *             Interacts with grappa to fetch registered asset info
 */
contract CrossMarginEngine is
    BaseEngine,
    PhysicalSettlement,
    IMarginEngine,
    IPhysicalSettlement,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using AccountUtil for Position[];
    using BalanceUtil for Balance[];
    using CrossMarginLib for CrossMarginAccount;
    using ProductIdUtil for uint40;
    using SafeCast for uint256;
    using SafeCast for int256;
    using TokenIdUtil for uint256;

    /*///////////////////////////////////////////////////////////////
                         State Variables V1
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => CrossMarginAccount structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => CrossMarginAccount) internal accounts;

    ///@dev contract that verifys permissions
    ///     if not set allows anyone to transact
    ///     checks msg.sender on execute & batchExecute
    ///     checks receipient on sendPayoutValue
    IWhitelist public whitelist;

    /*///////////////////////////////////////////////////////////////
                Constructor for implementation Contract
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    constructor(address _grappa, address _optionToken) BaseEngine(_grappa, _optionToken) initializer {}

    /*///////////////////////////////////////////////////////////////
                            Initializer
    //////////////////////////////////////////////////////////////*/

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init_unchained();
    }

    /*///////////////////////////////////////////////////////////////
                    Override Upgrade Permission
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Upgradable by the owner.
     *
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override {
        _checkOwner();
    }

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the whitelist contract
     * @param _whitelist is the address of the new whitelist
     */
    function setWhitelist(address _whitelist) external {
        _checkOwner();

        whitelist = IWhitelist(_whitelist);
    }

    /**
     * @notice Registers a new issuer
     * @param _subAccount is the address of the new issuer
     */
    function registerIssuer(address _subAccount) public override (PhysicalSettlement, IPhysicalSettlement) returns (uint16 id) {
        _checkOwner();

        id = PhysicalSettlement.registerIssuer(_subAccount);
    }

    /**
     * @dev set new settlement window
     * @param _window is the time from expiry that the option can be exercised
     */
    function setPhysicalSettlementWindow(uint256 _window) public override {
        _checkOwner();

        PhysicalSettlement.setPhysicalSettlementWindow(_window);
    }

    /**
     * @notice batch execute on multiple subAccounts
     * @dev    check margin after all subAccounts are updated
     *         because we support actions like `TransferCollateral` that moves collateral between subAccounts
     */
    function batchExecute(BatchExecute[] calldata batchActions) external nonReentrant {
        _checkPermissioned(msg.sender);

        uint256 i;
        for (i; i < batchActions.length;) {
            address subAccount = batchActions[i].subAccount;
            ActionArgs[] calldata actions = batchActions[i].actions;

            _execute(subAccount, actions);

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }

        for (i = 0; i < batchActions.length;) {
            if (!_isAccountAboveWater(batchActions[i].subAccount)) revert BM_AccountUnderwater();

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice execute multiple actions on one subAccounts
     * @dev    check margin all actions are applied
     */
    function execute(address _subAccount, ActionArgs[] calldata actions) external override nonReentrant {
        _checkPermissioned(msg.sender);

        _execute(_subAccount, actions);

        if (!_isAccountAboveWater(_subAccount)) revert BM_AccountUnderwater();
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _recipient receiver
     * @param _amount amount
     */
    function sendPayoutValue(address _asset, address _recipient, uint256 _amount) public override (BaseEngine, IMarginEngine) {
        _checkPermissioned(_recipient);

        BaseEngine.sendPayoutValue(_asset, _recipient, _amount);
    }

    /**
     * @dev calculate the payout for one token
     * @param _tokenId the token id
     * @return payoutPerToken amount paid
     */
    function getCashSettlementPerToken(uint256 _tokenId) public view override (BaseEngine, IMarginEngine) returns (uint256) {
        return BaseEngine.getCashSettlementPerToken(_tokenId);
    }

    /**
     * @notice settlement of physical token.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _settlement struct
     */
    function settlePhysicalToken(Settlement calldata _settlement) public override (PhysicalSettlement, IPhysicalSettlement) {
        _checkPermissioned(_settlement.debtor);

        PhysicalSettlement.settlePhysicalToken(_settlement);
    }

    /**
     * @dev calculate the debt and payout for one cash settled token
     * @param _tokenId  the gtoken id
     * @return settlement struct
     */
    function getPhysicalSettlementPerToken(uint256 _tokenId)
        public
        view
        override (PhysicalSettlement, IPhysicalSettlement)
        returns (Settlement memory)
    {
        return PhysicalSettlement.getPhysicalSettlementPerToken(_tokenId);
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return balances array of collaterals and amount (signed)
     */
    function getMinCollateral(address _subAccount) external view returns (Balance[] memory) {
        CrossMarginAccount memory account = accounts[_subAccount];

        return _getMinCollateral(account);
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();

        if (!accounts[_newSubAccount].isEmpty()) revert CM_AccountIsNotEmpty();
        accounts[_newSubAccount] = accounts[_subAccount];

        delete accounts[_subAccount];
    }

    /**
     * @dev view function to get all shorts, longs and collaterals
     */
    function marginAccounts(address _subAccount)
        external
        view
        returns (Position[] memory shorts, Position[] memory longs, Balance[] memory collaterals)
    {
        CrossMarginAccount memory account = accounts[_subAccount];

        return (account.shorts, account.longs, account.collaterals);
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param shorts positions.
     * @param longs positions.
     * @return balances array of collaterals and amount
     */
    function previewMinCollateral(Position[] memory shorts, Position[] memory longs) external view returns (Balance[] memory) {
        CrossMarginAccount memory account;

        account.shorts = shorts;
        account.longs = longs;

        return _getMinCollateral(account);
    }

    /**
     * ========================================================= **
     *             Override Internal Functions For Each Action
     * ========================================================= *
     */

    /**
     * @notice  settle the margin account at expiry
     * @dev     override this function from BaseEngine
     *             because we get the payout while updating the storage during settlement
     * @dev     this update the account storage
     */
    function _settle(address _subAccount) internal override {
        // update the account in state
        (Balance[] memory longDebts,, Balance[] memory shortPayouts) =
            accounts[_subAccount].settleAtExpiry(grappa, getPhysicalSettlementWindow());
        emit AccountSettled(_subAccount, longDebts, shortPayouts);
    }

    /**
     * ========================================================= **
     *               Override Sate changing functions             *
     * ========================================================= *
     */

    function _mintOption(address _subAccount, bytes calldata _data) internal override (BaseEngine, PhysicalSettlement) {
        // ensuring physical options are properly created
        PhysicalSettlement._mintOption(_subAccount, _data);
    }

    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data)
        internal
        virtual
        override (BaseEngine, PhysicalSettlement)
    {
        // ensuring physical options are properly created
        PhysicalSettlement._mintOptionIntoAccount(_subAccount, _data);
    }

    function _addCollateralToAccount(address _subAccount, uint8 collateralId, uint80 amount) internal override {
        accounts[_subAccount].addCollateral(collateralId, amount);
    }

    function _removeCollateralFromAccount(address _subAccount, uint8 collateralId, uint80 amount) internal override {
        accounts[_subAccount].removeCollateral(collateralId, amount);
    }

    function _increaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        accounts[_subAccount].mintOption(tokenId, amount);
    }

    function _decreaseShortInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        accounts[_subAccount].burnOption(tokenId, amount);
    }

    function _increaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        accounts[_subAccount].addOption(tokenId, amount);
    }

    function _decreaseLongInAccount(address _subAccount, uint256 tokenId, uint64 amount) internal override {
        accounts[_subAccount].removeOption(tokenId, amount);
    }

    /**
     * ========================================================= **
     *                 Override view functions for BaseEngine
     * ========================================================= *
     */

    /**
     * @dev because we override _settle(), this function is not used
     */
    // solhint-disable-next-line no-empty-blocks
    function _getAccountPayout(address) internal view override returns (uint8, uint80) {}

    /**
     * @dev return whether if an account is healthy.
     * @param _subAccount subaccount id
     * @return isHealthy true if account is in good condition, false if it's underwater (liquidatable)
     */
    function _isAccountAboveWater(address _subAccount) internal view override returns (bool) {
        CrossMarginAccount memory account = accounts[_subAccount];

        Balance[] memory balances = account.collaterals;

        Balance[] memory minCollateralAmounts = _getMinCollateral(account);

        for (uint256 i; i < minCollateralAmounts.length;) {
            (, Balance memory balance,) = balances.find(minCollateralAmounts[i].collateralId);

            if (balance.amount < minCollateralAmounts[i].amount) return false;

            unchecked {
                ++i;
            }
        }

        return true;
    }

    /**
     * @dev reverts if the account cannot add this token into the margin account.
     * @param tokenId tokenId
     */
    function _verifyLongTokenIdToAdd(uint256 tokenId) internal view override {
        (TokenType tokenType,, uint40 productId, uint64 expiry,,) = tokenId.parseTokenId();

        // engine only supports calls and puts
        if (tokenType != TokenType.CALL && tokenType != TokenType.PUT) revert CM_UnsupportedTokenType();

        if (block.timestamp > expiry) revert CM_Token_Expired();

        (, uint8 engineId,,,) = productId.parseProductId();

        // in the future reference a whitelist of engines
        if (engineId != grappa.engineIds(address(this))) revert CM_Not_Authorized_Engine();
    }

    /**
     * ========================================================= **
     *                         Internal Functions
     * ========================================================= *
     */

    /**
     * @notice gets access status of an address
     * @dev if whitelist address is not set, it ignores this
     * @param _address address
     */
    function _checkPermissioned(address _address) internal view {
        if (address(whitelist) != address(0) && !whitelist.engineAccess(_address)) revert NoAccess();
    }

    /**
     * @notice execute multiple actions on one subAccounts
     * @dev    also check access of msg.sender
     */
    function _execute(address _subAccount, ActionArgs[] calldata actions) internal {
        _assertCallerHasAccess(_subAccount);

        // update the account storage and do external calls on the flight
        for (uint256 i; i < actions.length;) {
            if (actions[i].action == ActionType.AddCollateral) {
                _addCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.RemoveCollateral) {
                _removeCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.MintShort) {
                _mintOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.MintShortIntoAccount) {
                _mintOptionIntoAccount(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.BurnShort) {
                _burnOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferLong) {
                _transferLong(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferShort) {
                _transferShort(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.TransferCollateral) {
                _transferCollateral(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.AddLong) {
                _addOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.RemoveLong) {
                _removeOption(_subAccount, actions[i].data);
            } else if (actions[i].action == ActionType.SettleAccount) {
                _settle(_subAccount);
            } else {
                revert CM_UnsupportedAction();
            }

            // increase i without checking overflow
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev get minimum collateral requirement for an account
     */
    function _getMinCollateral(CrossMarginAccount memory account) internal view returns (Balance[] memory) {
        return CrossMarginMath.getMinCollateralForPositions(grappa, account.shorts, account.longs);
    }
}
