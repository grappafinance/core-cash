// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// interfaces
import {IOracle} from "../interfaces/IOracle.sol";
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";

// inheriting contract
import {Settlement} from "./Settlement.sol";

// librarise
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";
import {SimpleMarginMath} from "./SimpleMargin/libraries/SimpleMarginMath.sol";
import {SimpleMarginLib} from "./SimpleMargin/libraries/SimpleMarginLib.sol";

// constants and types
import "../config/types.sol";
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   Grappa
 * @author  @antoncoding
 * @notice  Grappa is in the entry point to mint / burn option tokens
            Users can deposit collateral into SimpleMarginEngine and mint optionTokens (debt) out of it.
            Interacts with OptionToken to mint / burn.
            Interacts with Oracle to read spot price for assets and vol.
 */
contract Grappa is ReentrancyGuard, Settlement {
    using SimpleMarginMath for SimpleMarginEngineDetail;
    using SimpleMarginLib for Account;
    using SafeERC20 for IERC20;

    ///@dev maskedAccount => operator => authorized
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    mapping(uint160 => mapping(address => bool)) public authorized;

    constructor(address _optionToken) Settlement(_optionToken) {}

    /*///////////////////////////////////////////////////////////////
                                  Events
    //////////////////////////////////////////////////////////////*/
    event ProductConfigurationUpdated(
        uint32 productId,
        uint32 dUpper,
        uint32 dLower,
        uint32 rUpper,
        uint32 rLower,
        uint32 volMul
    );

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  execute array of actions on an account
     * @dev     expected to be called by account owners.
     */
    function execute(
        address _subAccount,
        uint8 _engineId,
        ActionArgs[] calldata actions
    ) external nonReentrant {
        _assertCallerHasAccess(_subAccount);
        // Account memory account = marginAccounts[_subAccount];

        address engine = engines[_engineId];

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral)
                _removeCollateral(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(engine, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(engine, _subAccount);

            // increase i without checking overflow
            unchecked {
                i++;
            }
        }
        _assertAccountHealth(engine, _subAccount);
    }

    function liquidate(
        address _engine,
        address _subAccount,
        uint256[] memory _tokensToBurn,
        uint256[] memory _amountsToBurn
    ) external {
        (uint8[] memory collateralIds, uint80[] memory amountsToPay) = IMarginEngine(_engine).liquidate(
            _subAccount,
            _tokensToBurn,
            _amountsToBurn
        );
        optionToken.batchBurn(msg.sender, _tokensToBurn, _amountsToBurn);

        for (uint256 i; i < collateralIds.length; ) {
            // send collatearl to liquidator
            IERC20(assets[collateralIds[i]].addr).safeTransfer(msg.sender, amountsToPay[i]);
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice  grant or revoke an account access to all your sub-accounts
     * @dev     expected to be call by account owner
     *          usually user should only give access to helper contracts
     * @param   _account account to update authorization
     * @param   _isAuthorized to grant or revoke access
     */
    function setAccountAccess(address _account, bool _isAuthorized) external {
        authorized[uint160(msg.sender) | 0xFF][_account] = _isAuthorized;
    }

    /** ========================================================= **
     *                 * -------------------- *                    *
     *                 |  Actions  Functions  |                    *
     *                 * -------------------- *                    *
     *    These functions all update account struct memory and     *
     *    deal with burning / minting or transfering collateral    *
     ** ========================================================= **/

    /**
     * @dev pull token from user, increase collateral in account memory
            the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        // update the account structure in memory
        IMarginEngine(engine).addCollateral(_subAccount, amount, collateralId);

        address collateral = address(assets[collateralId].addr);

        // collateral must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert MA_InvalidFromAddress();
        IERC20(collateral).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     * @param _data bytes data to decode
     */
    function _removeCollateral(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // todo: check expiry if has short

        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the account structure in memory
        IMarginEngine(engine).removeCollateral(_subAccount, collateralId, amount);

        address collateral = address(assets[collateralId].addr);

        // external calls
        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     * @param _data bytes data to decode
     */
    function _mintOption(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account structure in memory
        IMarginEngine(engine).mintOption(_subAccount, tokenId, amount);

        // mint the real option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     * @param _subAccount the id of the subaccount passed in
     */
    function _burnOption(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the account structure in memory
        IMarginEngine(engine).burnOption(_subAccount, tokenId, amount);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert MA_InvalidFromAddress();
        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address from) = abi.decode(_data, (uint256, address));

        // update the account structure in memory
        uint64 amount = IMarginEngine(engine).merge(_subAccount, tokenId);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert MA_InvalidFromAddress();

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(
        address engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (TokenType tokenType, address recipient) = abi.decode(_data, (TokenType, address));

        (uint256 tokenId, uint64 amount) = IMarginEngine(engine).split(_subAccount, tokenType);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     * @param _subAccount subaccount structure that will be update in place
     */
    function _settle(address engine, address _subAccount) internal {
        IMarginEngine(engine).settleAtExpiry(_subAccount);
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
     * @notice return if the calling address is eligible to access an subAccount address
     */
    function _assertCallerHasAccess(address _subAccount) internal view {
        if (_isPrimaryAccountFor(msg.sender, _subAccount)) return;

        // the sender is not the direct owner. check if he's authorized
        uint160 maskedAccountId = (uint160(_subAccount) | 0xFF);
        if (!authorized[maskedAccountId][msg.sender]) revert NoAccess();
    }

    /**
     * @dev make sure account is above water
     */
    function _assertAccountHealth(address engine, address _subAccount) internal view {
        if (!IMarginEngine(engine).isAccountHealthy(_subAccount)) revert MA_AccountUnderwater();
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _account account memory
     */
    function _getPayoutFromAccount(Account memory _account) internal view returns (uint80 reservedPayout) {
        (uint256 callPayout, uint256 putPayout) = (0, 0);
        if (_account.shortCallAmount > 0)
            (, callPayout) = getOptionPayout(_account.shortCallId, _account.shortCallAmount);
        if (_account.shortPutAmount > 0) (, putPayout) = getOptionPayout(_account.shortPutId, _account.shortPutAmount);
        return uint80(callPayout + putPayout);
    }
}
