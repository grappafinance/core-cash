// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IOptionToken} from "../../../interfaces/IOptionToken.sol";
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
            Interacts with OptionToken to mint / burn
            Interacts with grappa to fetch registered asset info
 */
contract FullMarginEngine is ReentrancyGuard, BaseEngine, IMarginEngine {
    using FullMarginLib for FullMarginAccount;
    using FullMarginMath for FullMarginDetail;
    using SafeERC20 for IERC20;
    using TokenIdUtil for uint256;

    IOptionToken public immutable optionToken;
    
    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => FullMarginAccount structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => FullMarginAccount) public marginAccounts;

    
    constructor(address _grappa, address _optionToken) BaseEngine(_grappa) {
        optionToken = IOptionToken(_optionToken);
    }

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event CollateralAdded(address subAccount, address collateral, uint256 amount);

    event CollateralRemoved(address subAccount, address collateral, uint256 amount);

    event OptionTokenMinted(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenBurned(address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenMerged(address subAccount, uint256 longToken, uint256 shortToken, uint64 amount);

    event OptionTokenSplit(address subAccount, uint256 spreadId, uint64 amount);

    event AccountSettled(address subAccount, uint256 payout);

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    function execute(address _subAccount, ActionArgs[] calldata actions) external nonReentrant {
        _assertCallerHasAccess(_subAccount);

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral)
                _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else revert EG_UnsupportedAction();

            // increase i without checking overflow
            unchecked {
                i++;
            }
        }
        if (!_isAccountHealthy(_subAccount)) revert FM_AccountUnderwater();
    }

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
     *       These functions all update account memory             *
     ** ========================================================= **/

    /**
     * @dev pull token from user, increase collateral in account memory
            the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert FM_InvalidFromAddress();

        // update the account in memory
        marginAccounts[_subAccount].addCollateral(amount, collateralId);

        address collateral = grappa.assets(collateralId).addr;

        IERC20(collateral).safeTransferFrom(from, address(this), amount);

        emit CollateralAdded(_subAccount, collateral, amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     * @param _data bytes data to decode
     */
    function _removeCollateral(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account in memory
        marginAccounts[_subAccount].removeCollateral(amount, collateralId);

        address collateral = grappa.assets(collateralId).addr;

        emit CollateralRemoved(_subAccount, collateral, amount);

        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     * @param _data bytes data to decode
     */
    function _mintOption(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        emit OptionTokenMinted(_subAccount, tokenId, amount);

        // update the account in memory
        marginAccounts[_subAccount].mintOption(tokenId, amount);

        // mint the real option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _burnOption(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert FM_InvalidFromAddress();

        emit OptionTokenBurned(_subAccount, tokenId, amount);

        // update the account in memory
        marginAccounts[_subAccount].burnOption(tokenId, amount);

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 longId, uint256 shortId, address from, uint64 amount) = abi.decode(
            _data,
            (uint256, uint256, address, uint64)
        );

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert FM_InvalidFromAddress();

        _verifyMergeTokenIds(longId, shortId);

        emit OptionTokenMerged(_subAccount, longId, shortId, amount);

        // update the account in memory
        marginAccounts[_subAccount].merge(shortId, longId, amount);

        // this line will revert if usre is trying to burn an un-authrized tokenId
        optionToken.burn(from, longId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 spreadId, uint64 amount, address recipient) = abi.decode(_data, (uint256, uint64, address));

        uint256 tokenId = _verifySpreadIdAndGetLong(spreadId);

        emit OptionTokenSplit(_subAccount, spreadId, amount);

        // update the account in memory
        marginAccounts[_subAccount].split(spreadId, amount);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     */
    function _settle(address _subAccount) internal {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        (, , uint256 payout) = grappa.getPayout(account.tokenId, account.shortAmount);

        emit AccountSettled(_subAccount, payout);

        marginAccounts[_subAccount].settleAtExpiry(uint80(payout));
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

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

    /**
     * @dev return whether if an account is healthy.
     * @param _subAccount account to check
     * @return isHealthy true if account is in good condition, false if it's liquidatable
     */
    function _isAccountHealthy(address _subAccount) internal view returns (bool isHealthy) {
        FullMarginAccount memory account = marginAccounts[_subAccount];
        FullMarginDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = detail.getMinCollateral();
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(FullMarginAccount memory account)
        internal
        view
        returns (FullMarginDetail memory detail)
    {
        (TokenType tokenType, uint32 productId, , uint64 longStrike, uint64 shortStrike) = account
            .tokenId
            .parseTokenId();

        (, , uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        bool collateralizedWithStrike = collateralId == strikeId;

        uint8 collateralDecimals = grappa.assets(collateralId).decimals;

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
