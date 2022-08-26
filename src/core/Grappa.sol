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
import {Registry} from "./Registry.sol";

// librarise
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";
import {NumberUtil} from "../libraries/NumberUtil.sol";
import {MoneynessLib} from "../libraries/MoneynessLib.sol";

// constants and types
import "../config/types.sol";
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";

/**
 * @title   Grappa
 * @author  @antoncoding
 * @notice  Grappa is in the entry point to mint / burn option tokens
            Interacts with different MarginEngines to mint optionTokens.
            Interacts with OptionToken to mint / burn.
 */
contract Grappa is ReentrancyGuard, Registry {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using TokenIdUtil for uint256;
    using ProductIdUtil for uint32;

    ///@dev maskedAccount => operator => authorized
    ///     every account can authorize any amount of addresses to modify all sub-accounts he controls.
    mapping(uint160 => mapping(address => bool)) public authorized;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;
    // IMarginEngine public immutable engine;
    IOracle public immutable oracle;

    constructor(address _optionToken, address _oracle) {
        optionToken = IOptionToken(_optionToken);
        oracle = IOracle(_oracle);
    }

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

    event AccountAuthorizationUpdate(address account, address spender, bool isAuthorized);

    event OptionSettled(address account, uint256 tokenId, uint256 amountSettled, uint256 payout);

    event CollateralAdded(address engine, address subAccount, address collateral, uint256 amount);

    event CollateralRemoved(address engine, address subAccount, address collateral, uint256 amount);

    event OptionTokenMinted(address engine, address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenBurned(address engine, address subAccount, uint256 tokenId, uint256 amount);

    event OptionTokenMerged(address engine, address subAccount, uint256 longToken, uint256 shortToken, uint64 amount);

    /*///////////////////////////////////////////////////////////////
                        External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  execute array of actions on an account
     * @dev     expected to be called by account owners.
     */
    function execute(
        uint8 _engineId,
        address _subAccount,
        ActionArgs[] calldata actions
    ) external nonReentrant {
        _assertCallerHasAccess(_subAccount);

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

    /**
     * @notice burn option token to liquidate an account
     *
     */
    function liquidate(
        address _engine,
        address _subAccount,
        uint256[] memory _tokensToBurn,
        uint256[] memory _amountsToBurn
    ) external returns (address collateral, uint80 amountToPay) {
        // liquidate account structure and payout
        (collateral, amountToPay) = IMarginEngine(_engine).liquidate(
            _subAccount,
            msg.sender,
            _tokensToBurn,
            _amountsToBurn
        );
        // burn the tokens
        optionToken.batchBurn(msg.sender, _tokensToBurn, _amountsToBurn);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     */
    function settleOption(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        (address engine, address collateral, uint256 payout) = getPayout(_tokenId, uint64(_amount));

        optionToken.burn(_account, _tokenId, _amount);

        IMarginEngine(engine).payCashValue(collateral, _account, payout);

        emit OptionSettled(_account, _tokenId, _amount, payout);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     
     */
    function batchSettleOptions(
        address _account,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external {
        if (_tokenIds.length != _amounts.length) revert GP_WrongArgumentLength();

        if (_tokenIds.length == 0) return;

        optionToken.batchBurn(_account, _tokenIds, _amounts);

        address lastCollateral;
        address lastEngine;

        uint256 lastTotalPayout;

        for (uint256 i; i < _tokenIds.length; ) {
            (address engine, address collateral, uint256 payout) = getPayout(_tokenIds[i], uint64(_amounts[i]));

            // if engine or collateral changes, payout and clear temporary parameters
            if (lastEngine == address(0)) {
                lastEngine = engine;
                lastCollateral = collateral;
            } else if (engine != lastEngine || lastCollateral != collateral) {
                IMarginEngine(lastEngine).payCashValue(lastCollateral, _account, lastTotalPayout);
                lastTotalPayout = 0;
                lastEngine = engine;
                lastCollateral = collateral;
            }

            lastTotalPayout += payout;

            emit OptionSettled(_account, _tokenIds[i], _amounts[i], payout);

            unchecked {
                i++;
            }
        }

        IMarginEngine(lastEngine).payCashValue(lastCollateral, _account, lastTotalPayout);
    }

    /**
     * @dev calculate the payout for one option token
     *
     * @param _tokenId  token id of option token
     * @param _amount   amount to settle
     *
     * @return engine engine to settle
     * @return collateral asset to settle in
     * @return payout amount paid
     **/
    function getPayout(uint256 _tokenId, uint64 _amount)
        public
        view
        returns (
            address engine,
            address collateral,
            uint256 payout
        )
    {
        uint256 payoutPerOption;
        (engine, collateral, payoutPerOption) = _getPayoutPerToken(_tokenId);
        payout = payoutPerOption.mulDivDown(_amount, UNIT);
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

        emit AccountAuthorizationUpdate(msg.sender, _account, _isAuthorized);
    }

    /** ========================================================= **
     *                 * -------------------- *                    *
     *                 |  Actions  Functions  |                    *
     *                 * -------------------- *                    *
     *    These functions all call engine to update account info   *
     *    & deal with burning / minting or transfering collateral  *
     ** ========================================================= **/

    /**
     * @dev pull token from user, increase collateral in account memory
            the collateral has to be provided by either caller, or the primary owner of subaccount
     */
    function _addCollateral(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();

        address collateral = address(assets[collateralId].addr);

        // update the data structure in corresponding engine, and pull asset to the engine
        IMarginEngine(_engine).increaseCollateral(_subAccount, from, collateral, collateralId, amount);

        emit CollateralAdded(_engine, _subAccount, collateral, amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     * @param _data bytes data to decode
     */
    function _removeCollateral(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        address collateral = address(assets[collateralId].addr);

        // update the data structure in corresponding engine
        IMarginEngine(_engine).decreaseCollateral(_subAccount, recipient, collateral, collateralId, amount);

        emit CollateralRemoved(_engine, _subAccount, collateral, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     * @param _data bytes data to decode
     */
    function _mintOption(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        _assertIsAuthorizedEngineForToken(_engine, tokenId);

        // update the data structure in corresponding engine
        IMarginEngine(_engine).increaseDebt(_subAccount, tokenId, amount);

        // mint the real option token
        optionToken.mint(recipient, tokenId, amount);

        emit OptionTokenMinted(_engine, _subAccount, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     * @param _subAccount the id of the subaccount passed in
     */
    function _burnOption(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // update the data structure in corresponding engine
        IMarginEngine(_engine).decreaseDebt(_subAccount, tokenId, amount);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();
        optionToken.burn(from, tokenId, amount);

        emit OptionTokenBurned(_engine, _subAccount, tokenId, amount);
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 longTokenId, uint256 shortTokenId, address from, uint64 amount) = abi.decode(
            _data,
            (uint256, uint256, address, uint64)
        );

        _verifyMergeTokenIds(longTokenId, shortTokenId);

        // update the data structure in corresponding engine
        IMarginEngine(_engine).merge(_subAccount, shortTokenId, longTokenId, amount);

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();

        optionToken.burn(from, longTokenId, amount);

        emit OptionTokenMerged(_engine, _subAccount, longTokenId, shortTokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(
        address _engine,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 spreadId, address recipient) = abi.decode(_data, (uint256, address));

        // update the data structure in corresponding engine
        (uint256 tokenId, uint64 amount) = IMarginEngine(_engine).split(_subAccount, spreadId);

        _assertIsAuthorizedEngineForToken(_engine, tokenId);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     * @param _subAccount subaccount structure that will be update in place
     */
    function _settle(address _engine, address _subAccount) internal {
        IMarginEngine(_engine).settleAtExpiry(_subAccount);
    }

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

    /**
     * @dev calculate the payout for one option token
     *
     * @param _tokenId  token id of option token
     *
     * @return collateral asset to settle in
     * @return payoutPerOption amount paid
     **/
    function _getPayoutPerToken(uint256 _tokenId)
        internal
        view
        returns (
            address,
            address,
            uint256 payoutPerOption
        )
    {
        (TokenType tokenType, uint32 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) = TokenIdUtil
            .parseTokenId(_tokenId);

        if (block.timestamp < expiry) revert GP_NotExpired();

        (
            address engine,
            address underlying,
            address strike,
            address collateral,
            uint8 collateralDecimals
        ) = getDetailFromProductId(productId);

        // expiry price of underlying, denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 expiryPrice = oracle.getPriceAtExpiry(underlying, strike, expiry);

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;
        if (tokenType == TokenType.CALL) {
            cashValue = MoneynessLib.getCallCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.CALL_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitCallSpread(expiryPrice, longStrike, shortStrike);
        } else if (tokenType == TokenType.PUT) {
            cashValue = MoneynessLib.getPutCashValue(expiryPrice, longStrike);
        } else if (tokenType == TokenType.PUT_SPREAD) {
            cashValue = MoneynessLib.getCashValueDebitPutSpread(expiryPrice, longStrike, shortStrike);
        }

        // the following logic convert cash value (amount worth) if collateral is not strike:
        if (collateral == underlying) {
            // collateral is underlying. payout should be devided by underlying price
            cashValue = cashValue.mulDivDown(UNIT, expiryPrice);
        } else if (collateral != strike) {
            // collateral is not underlying nor strike
            uint256 collateralPrice = oracle.getPriceAtExpiry(collateral, strike, expiry);
            cashValue = cashValue.mulDivDown(UNIT, collateralPrice);
        }
        payoutPerOption = cashValue.convertDecimals(UNIT_DECIMALS, collateralDecimals);

        return (engine, collateral, payoutPerOption);
    }

    /**
     * @notice return if {_primary} address is the primary account for {_subAccount}
     */
    function _isPrimaryAccountFor(address _primary, address _subAccount) internal pure returns (bool) {
        return (uint160(_primary) | 0xFF) == (uint160(_subAccount) | 0xFF);
    }

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
     * @dev make sure account is above water
     * @param _engine address of the margin engine
     * @param _subAccount sub account id
     */
    function _assertAccountHealth(address _engine, address _subAccount) internal view {
        if (!IMarginEngine(_engine).isAccountHealthy(_subAccount)) revert GP_AccountUnderwater();
    }

    /**
     * @dev revert if the calling engine can not mint the token.
     * @param _engine address of the engine
     * @param _tokenId tokenid
     */
    function _assertIsAuthorizedEngineForToken(address _engine, uint256 _tokenId) internal view {
        (, uint32 productId, , , ) = TokenIdUtil.parseTokenId(_tokenId);
        address engine = getEngineFromProductId(productId);
        if (_engine != engine) revert GP_Not_Authorized_Engine();
    }

    /**
     * @dev make sure the user can merge 2 tokens (1 long and 1 short) into a spread
     * @param longId id of the incoming token to be merged
     * @param shortId id of the existing short position
     */
    function _verifyMergeTokenIds(uint256 longId, uint256 shortId) internal pure {
        // get token attribute for incoming token
        (TokenType longType, uint32 productId, uint64 expiry, uint64 longStrike, ) = longId.parseTokenId();

        // token being added can only be call or put
        if (longType != TokenType.CALL && longType != TokenType.PUT) revert AM_CannotMergeSpread();

        (TokenType shortType, uint32 productId_, uint64 expiry_, uint64 shortStrike, ) = shortId.parseTokenId();

        // check that the merging token (long) has the same property as existing short
        if (shortType != longType) revert AM_MergeTypeMismatch();
        if (productId_ != productId) revert AM_MergeProductMismatch();
        if (expiry_ != expiry) revert AM_MergeExpiryMismatch();
        if (longStrike == shortStrike) revert AM_MergeWithSameStrike();
    }
}
