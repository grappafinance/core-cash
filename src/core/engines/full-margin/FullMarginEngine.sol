// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";
import {IVolOracle} from "../../../interfaces/IVolOracle.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

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

/**
 * @title   FullMarginEngine
 * @author  @antoncoding
 * @notice  Fully collateralized margin engine
            Users can deposit collateral into FullMargin and mint optionTokens (debt) out of it.
            Listen to calls from Grappa to update accountings
 */
contract FullMarginEngine is IMarginEngine, Ownable {
    using FullMarginLib for FullMarginAccount;
    using FullMarginMath for FullMarginDetail;
    using SafeERC20 for IERC20;

    IGrappa public immutable grappa;
    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => FullMarginAccount structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => FullMarginAccount) public marginAccounts;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _grappa) {
        grappa = IGrappa(_grappa);
    }

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * todo: consider movingg this to viewer contract
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        FullMarginDetail memory detail = _getAccountDetail(account);
        minCollateral = detail.getMinCollateral();
    }

    function isAccountHealthy(address _subAccount) external view returns (bool) {
        return _isAccountHealthy(marginAccounts[_subAccount]);
    }

    /**
     * @notice  liquidate an account
     * @dev     fully collateralized options cannot be liquidated
     */
    function liquidate(
        address, /**_subAccount**/
        address, /**_liquidator**/
        uint256[] memory, /**tokensToBurn**/
        uint256[] memory /**amountsToBurn**/
    )
        external
        pure
        returns (
            address, /*collateral*/
            uint80 /*collateralToPay*/
        )
    {
        revert FM_NoLiquidation();
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
    ) external {
        _assertCallerIsGrappa();

        IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    /**
     * @notice  move an account to someone else
     * @dev     expected to be call by account owner
     * @param _subAccount the id of subaccount to trnasfer
     * @param _newSubAccount the id of receiving account
     */
    function transferAccount(address _subAccount, address _newSubAccount) external {
        if (!_isPrimaryAccountFor(msg.sender, _subAccount)) revert NoAccess();

        if (!marginAccounts[_newSubAccount].isEmpty()) revert AM_AccountIsNotEmpty();
        marginAccounts[_newSubAccount] = marginAccounts[_subAccount];

        delete marginAccounts[_subAccount];
    }

    /** ========================================================= **
     *                 * -------------------- *                    *
     *                 |  Actions  Functions  |                    *
     *                 * -------------------- *                    *
     *       These functions all update account storages           *
     ** ========================================================= **/

    /**
     * @dev increase the collateral for an account
     */
    function increaseCollateral(
        address _subAccount,
        address _from,
        address _collateral,
        uint8 _collateralId,
        uint80 _amount
    ) external {
        _assertCallerIsGrappa();

        // update the account structure in storage
        marginAccounts[_subAccount].addCollateral(_amount, _collateralId);

        IERC20(_collateral).safeTransferFrom(_from, address(this), _amount);
    }

    /**
     * @dev decrease collateral in account
     */
    function decreaseCollateral(
        address _subAccount,
        address _recipient,
        address _collateral,
        uint8 _collateralId,
        uint80 _amount
    ) external {
        _assertCallerIsGrappa();

        // todo: check if vault has expired short positions

        // update the account structure in storage
        marginAccounts[_subAccount].removeCollateral(_amount, _collateralId);

        IERC20(_collateral).safeTransfer(_recipient, _amount);
    }

    /**
     * @dev increase short position (debt) in account
     */
    function increaseDebt(
        address _subAccount,
        uint256 _optionId,
        uint64 _amount
    ) external {
        _assertCallerIsGrappa();

        // update the account structure in storage
        marginAccounts[_subAccount].mintOption(_optionId, _amount);
    }

    /**
     * @dev decrease the short position (debt) in account
     */
    function decreaseDebt(
        address _subAccount,
        uint256 _optionId,
        uint64 _amount
    ) external {
        _assertCallerIsGrappa();

        // update the account structure in storage
        marginAccounts[_subAccount].burnOption(_optionId, _amount);
    }

    /**
     * @dev change the short position to spread. This will reduce collateral requirement
     */
    function merge(
        address _subAccount,
        uint256 _shortTokenId,
        uint256 _longTokenId,
        uint64 _amount
    ) external {
        _assertCallerIsGrappa();

        // update the account in storage
        marginAccounts[_subAccount].merge(_shortTokenId, _longTokenId, _amount);
    }

    /**
     * @dev Change existing spread position to short. This should increase collateral requirement
     */
    function split(
        address _subAccount,
        uint256 _spreadId,
        uint64 _amount
    ) external {
        _assertCallerIsGrappa();

        // update the account
        marginAccounts[_subAccount].split(_spreadId, _amount);
    }

    /**
     * @notice  settle the margin account at expiry
     */
    function settleAtExpiry(address _subAccount) external {
        // clear the debt in account, and deduct the collateral with reservedPayout
        // this will NOT revert even if account has less collateral than it should have reserved for payout.
        _assertCallerIsGrappa();

        FullMarginAccount memory account = marginAccounts[_subAccount];

        uint80 reservedPayout = _getPayoutFromAccount(account);

        // update the account
        marginAccounts[_subAccount].settleAtExpiry(reservedPayout);
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
     * @notice revert if called by non-grappa controller
     */
    function _assertCallerIsGrappa() internal view {
        if (msg.sender != address(grappa)) revert NoAccess();
    }

    /**
     * @dev return whether if an account is healthy.
     * @param account account structure in memory
     * @return isHealthy true if account is in good condition, false if it's liquidatable
     */
    function _isAccountHealthy(FullMarginAccount memory account) internal view returns (bool isHealthy) {
        FullMarginDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = detail.getMinCollateral();
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _account account memory
     */
    function _getPayoutFromAccount(FullMarginAccount memory _account) internal view returns (uint80 reservedPayout) {
        (, , uint256 payout) = grappa.getPayout(_account.tokenId, _account.shortAmount);

        return uint80(payout);
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(FullMarginAccount memory account)
        internal
        view
        returns (FullMarginDetail memory detail)
    {
        (TokenType tokenType, uint32 productId, , uint64 longStrike, uint64 shortStrike) = TokenIdUtil.parseTokenId(
            account.tokenId
        );

        (, , , uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        uint8 collateralDecimals = grappa.assets(collateralId).decimals;

        detail = FullMarginDetail({
            shortAmount: account.shortAmount,
            longStrike: shortStrike,
            shortStrike: longStrike,
            collateralAmount: account.collateralAmount,
            collateralDecimals: collateralDecimals,
            tokenType: tokenType
        });
    }
}
