// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// interfaces
import {IOracle} from "../../../interfaces/IOracle.sol";
import {IOptionToken} from "../../../interfaces/IOptionToken.sol";
import {IGrappa} from "../../../interfaces/IGrappa.sol";
import {IMarginEngine} from "../../../interfaces/IMarginEngine.sol";
import {IVolOracle} from "../../../interfaces/IVolOracle.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// librarise
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";
import {AdvancedMarginMath} from "./AdvancedMarginMath.sol";
import {AdvancedMarginLib} from "./AdvancedMarginLib.sol";

// constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title   AdvancedMarginEngine
 * @author  @antoncoding
 * @notice  AdvancedMarginEngine is in charge of maintaining margin requirement for partial collateralized options
            Please see AdvancedMarginMath.sol for detailed partial collat calculation
            Interacts with VolOracle to read vol
            Listen to calls from Grappa to update accountings
 */
contract AdvancedMarginEngine is BaseEngine, IMarginEngine, Ownable, ReentrancyGuard {
    using AdvancedMarginMath for AdvancedMarginDetail;
    using AdvancedMarginLib for Account;
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;

    IGrappa public immutable grappa;
    IOptionToken public immutable optionToken;
    IOracle public immutable oracle;
    IVolOracle public immutable volOracle;

    /*///////////////////////////////////////////////////////////////
                                  Variables
    //////////////////////////////////////////////////////////////*/

    ///@dev subAccount => Account structure.
    ///     subAccount can be an address similar to the primary account, but has the last 8 bits different.
    ///     this give every account access to 256 sub-accounts
    mapping(address => Account) public marginAccounts;

    ///@dev mapping of productId to AdvancedMargin Parameters
    mapping(uint32 => ProductMarginParams) public productParams;

    // solhint-disable-next-line no-empty-blocks
    constructor(
        address _grappa,
        address _oracle,
        address _volOracle,
        address _optionToken
    ) {
        grappa = IGrappa(_grappa);
        oracle = IOracle(_oracle);
        volOracle = IVolOracle(_volOracle);
        optionToken = IOptionToken(_optionToken);
    }

    /*///////////////////////////////////////////////////////////////
                                  Events
    //////////////////////////////////////////////////////////////*/

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

    function execute(address _subAccount, ActionArgs[] calldata actions) external nonReentrant {
        _assertCallerHasAccess(_subAccount);

        Account memory account = marginAccounts[_subAccount];

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral)
                _removeCollateral(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MergeOptionToken) _merge(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SplitOptionToken) _split(account, _subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(account, _subAccount);
            else revert("unsupported");

            // increase i without checking overflow
            unchecked {
                i++;
            }
        }
        if (!_isAccountHealthy(account)) revert GP_AccountUnderwater();

        marginAccounts[_subAccount] = account;
    }

    function previewMinCollateral(address _subAccount, ActionArgs[] calldata actions) external view returns (uint256) {
        return 0;
    }

    /**
     * todo: consider moving this to viewer contract
     * @notice get minimum collateral needed for a margin account
     * @param _subAccount account id.
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function getMinCollateral(address _subAccount) external view returns (uint256 minCollateral) {
        Account memory account = marginAccounts[_subAccount];
        AdvancedMarginDetail memory detail = _getAccountDetail(account);

        minCollateral = _getMinCollateral(detail);
    }

    function isAccountHealthy(address _subAccount) external view returns (bool) {
        return _isAccountHealthy(marginAccounts[_subAccount]);
    }

    /**
     * @notice  liquidate an account:
     *          burning the token the account is shorted (repay the debt),
     *          and get the collateral from the margin account.
     * @dev     expected to be called by liquidators
     * @param _subAccount account to liquidate
     * @param tokensToBurn arrays of token burned
     * @param amountsToBurn amounts burned
     */
    function liquidate(
        address _subAccount,
        uint256[] memory tokensToBurn,
        uint256[] memory amountsToBurn
    ) external returns (address collateral, uint80 collateralToPay) {
        uint256 repayCallAmount = amountsToBurn[0];
        uint256 repayPutAmount = amountsToBurn[1];

        Account memory account = marginAccounts[_subAccount];

        if (account.shortCallId != tokensToBurn[0]) revert AM_WrongIdToLiquidate();
        if (account.shortPutId != tokensToBurn[1]) revert AM_WrongIdToLiquidate();

        if (_isAccountHealthy(account)) revert AM_AccountIsHealthy();

        bool hasShortCall = account.shortCallAmount != 0;
        bool hasShortPut = account.shortPutAmount != 0;

        // compute portion of the collateral the liquidator is repaying, in BPS.
        // @note: expected to lost precision becuase of performing division before multiplication
        uint256 portionBPS;
        if (hasShortCall && hasShortPut) {
            // if the account is short call and put at the same time,
            // amounts to liquidate needs to be the same portion of short call and short put amount.
            uint256 callPortionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
            uint256 putPortionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
            if (callPortionBPS != putPortionBPS) revert AM_WrongRepayAmounts();
            portionBPS = callPortionBPS;
        } else if (hasShortCall) {
            // account only short call
            if (repayPutAmount != 0) revert AM_WrongRepayAmounts();
            portionBPS = (repayCallAmount * BPS) / account.shortCallAmount;
        } else {
            // if account is underwater, it must have shortCall or shortPut. in this branch it will sure have shortPutAmount > 0;
            // account only short put
            if (repayCallAmount != 0) revert AM_WrongRepayAmounts();
            portionBPS = (repayPutAmount * BPS) / account.shortPutAmount;
        }

        // update account's debt and perform "safe" external calls
        if (hasShortCall) {
            optionToken.burn(msg.sender, account.shortCallId, amountsToBurn[0]);
            account.burnOption(account.shortCallId, uint64(repayCallAmount));
        }
        if (hasShortPut) {
            optionToken.burn(msg.sender, account.shortPutId, amountsToBurn[1]);
            account.burnOption(account.shortPutId, uint64(repayPutAmount));
        }

        // update account's collateral
        // address collateral = grappa.assets(account.collateralId);
        collateralToPay = uint80((account.collateralAmount * portionBPS) / BPS);

        collateral = grappa.assets(account.collateralId).addr;

        // if liquidator is trying to remove more collateral than owned, this line will revert
        account.removeCollateral(collateralToPay, account.collateralId);

        // write new accout to storage
        marginAccounts[_subAccount] = account;

        IERC20(collateral).safeTransfer(msg.sender, collateralToPay);
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

    /**
     * @notice set the margin config for specific productId
     * @dev    expected to be used by Owner or governance
     * @param _productId product id
     * @param _dUpper (sec) max time to expiry to offer a collateral requirement discount
     * @param _dLower (sec) min time to expiry to offer a collateral requirement discount
     * @param _rUpper (BPS) discount ratio if the time to expiry is at the upper bound
     * @param _rLower (BPS) discount ratio if the time to expiry is at the lower bound
     * @param _volMultiplier (BPS) multiplier used to apply to vol from oracle
     */
    function setProductMarginConfig(
        uint32 _productId,
        uint32 _dUpper,
        uint32 _dLower,
        uint32 _rUpper,
        uint32 _rLower,
        uint32 _volMultiplier
    ) external onlyOwner {
        productParams[_productId] = ProductMarginParams({
            dUpper: _dUpper,
            dLower: _dLower,
            sqrtDUpper: uint32(FixedPointMathLib.sqrt(uint256(_dUpper))),
            sqrtDLower: uint32(FixedPointMathLib.sqrt(uint256(_dLower))),
            rUpper: _rUpper,
            rLower: _rLower,
            volMultiplier: _volMultiplier
        });

        emit ProductConfigurationUpdated(_productId, _dUpper, _dLower, _rUpper, _rLower, _volMultiplier);
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
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (address from, uint80 amount, uint8 collateralId) = abi.decode(_data, (address, uint80, uint8));

        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();

        // update the data structure in memory, and pull asset to the engine
        _account.addCollateral(amount, collateralId);

        address collateral = grappa.assets(collateralId).addr;

        IERC20(collateral).safeTransferFrom(from, address(this), amount);

        emit CollateralAdded(_subAccount, collateral, amount);
    }

    /**
     * @dev push token to user, decrease collateral in account memory
     * @param _data bytes data to decode
     */
    function _removeCollateral(
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint80 amount, address recipient, uint8 collateralId) = abi.decode(_data, (uint80, address, uint8));

        // update the data structure in corresponding engine
        _account.removeCollateral(amount, collateralId);

        address collateral = grappa.assets(collateralId).addr;

        emit CollateralRemoved(_subAccount, collateral, amount);

        IERC20(collateral).safeTransfer(recipient, amount);
    }

    /**
     * @dev mint option token to user, increase short position (debt) in account memory
     * @param _data bytes data to decode
     */
    function _mintOption(
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address recipient, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        emit OptionTokenMinted(_subAccount, tokenId, amount);

        // update the account in memory
        _account.mintOption(tokenId, amount);

        // mint the real option token
        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @dev burn option token from user, decrease short position (debt) in account memory
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _burnOption(
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 tokenId, address from, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();

        emit OptionTokenBurned(_subAccount, tokenId, amount);

        // update the account in memory
        _account.burnOption(tokenId, amount);

        optionToken.burn(from, tokenId, amount);
    }

    /**
     * @dev burn option token and change the short position to spread. This will reduce collateral requirement
            the option has to be provided by either caller, or the primary owner of subaccount
     * @param _data bytes data to decode
     */
    function _merge(
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 longTokenId, uint256 shortTokenId, address from, uint64 amount) = abi.decode(
            _data,
            (uint256, uint256, address, uint64)
        );

        // token being burn must come from caller or the primary account for this subAccount
        if (from != msg.sender && !_isPrimaryAccountFor(from, _subAccount)) revert GP_InvalidFromAddress();

        _verifyMergeTokenIds(longTokenId, shortTokenId);

        emit OptionTokenMerged(_subAccount, longTokenId, shortTokenId, amount);

        // update the data structure in corresponding engine
        _account.merge(shortTokenId, longTokenId, amount);

        // this line will revert if usre is trying to burn an un-authrized tokenId
        optionToken.burn(from, longTokenId, amount);
    }

    /**
     * @dev Change existing spread position to short, and mint option token for recipient
     * @param _subAccount subaccount that will be update in place
     */
    function _split(
        Account memory _account,
        address _subAccount,
        bytes memory _data
    ) internal {
        // decode parameters
        (uint256 spreadId, uint64 amount, address recipient) = abi.decode(_data, (uint256, uint64, address));

        uint256 tokenId = _verifySpreadIdAndGetLong(spreadId);

        emit OptionTokenSplit(_subAccount, spreadId, amount);

        // update the data structure in corresponding engine
        _account.split(spreadId, amount);

        optionToken.mint(recipient, tokenId, amount);
    }

    /**
     * @notice  settle the margin account at expiry
     * @dev     this update the account memory in-place
     */
    function _settle(Account memory _account, address _subAccount) internal {
        uint256 payout = _getPayoutFromAccount(_account);

        emit AccountSettled(_subAccount, payout);

        _account.settleAtExpiry(uint80(payout));
    }

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

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
    function _isAccountHealthy(Account memory account) internal view returns (bool isHealthy) {
        AdvancedMarginDetail memory detail = _getAccountDetail(account);
        uint256 minCollateral = _getMinCollateral(detail);
        isHealthy = account.collateralAmount >= minCollateral;
    }

    /**
     * @notice get minimum collateral needed for a margin account
     * @param detail account memory dtail
     * @return minCollateral minimum collateral required, in collateral asset's decimals
     */
    function _getMinCollateral(AdvancedMarginDetail memory detail) internal view returns (uint256 minCollateral) {
        ProductAssets memory product = _getProductAssets(detail.productId);

        // read spot price of the product, denominated in {UNIT_DECIMALS}.
        // Pass in 0 if margin account has not debt
        uint256 spotPrice;
        uint256 vol;
        if (detail.productId != 0) {
            spotPrice = oracle.getSpotPrice(product.underlying, product.strike);
            vol = volOracle.getImpliedVol(product.underlying);
        }

        // need to pass in collateral/strike price. Pass in 0 if collateral is strike to save gas.
        uint256 collateralStrikePrice = 0;
        if (product.collateral == product.underlying) collateralStrikePrice = spotPrice;
        else if (product.collateral != product.strike) {
            collateralStrikePrice = oracle.getSpotPrice(product.collateral, product.strike);
        }

        uint256 minCollateralInUnit = detail.getMinCollateral(
            product,
            spotPrice,
            collateralStrikePrice,
            vol,
            productParams[detail.productId]
        );

        minCollateral = minCollateralInUnit.convertDecimals(UNIT_DECIMALS, product.collateralDecimals);
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _account account memory
     */
    function _getPayoutFromAccount(Account memory _account) internal view returns (uint80 reservedPayout) {
        (uint256 callPayout, uint256 putPayout) = (0, 0);
        if (_account.shortCallAmount > 0)
            (, , callPayout) = grappa.getPayout(_account.shortCallId, _account.shortCallAmount);
        if (_account.shortPutAmount > 0)
            (, , putPayout) = grappa.getPayout(_account.shortPutId, _account.shortPutAmount);
        return uint80(callPayout + putPayout);
    }

    /**
     * @notice  convert Account struct from storage to in-memory detail struct
     */
    function _getAccountDetail(Account memory account) internal pure returns (AdvancedMarginDetail memory detail) {
        detail = AdvancedMarginDetail({
            putAmount: account.shortPutAmount,
            callAmount: account.shortCallAmount,
            longPutStrike: 0,
            shortPutStrike: 0,
            longCallStrike: 0,
            shortCallStrike: 0,
            expiry: 0,
            collateralAmount: account.collateralAmount,
            productId: 0
        });

        // if it contains a call
        if (account.shortCallId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = TokenIdUtil.parseTokenId(account.shortCallId);
            // the short position of the account is the long of the minted optionToken
            detail.shortCallStrike = longStrike;
            detail.longCallStrike = shortStrike;
        }

        // if it contains a put
        if (account.shortPutId != 0) {
            (, , , uint64 longStrike, uint64 shortStrike) = TokenIdUtil.parseTokenId(account.shortPutId);

            // the short position of the account is the long of the minted optionToken
            detail.shortPutStrike = longStrike;
            detail.longPutStrike = shortStrike;
        }

        // parse common field
        // use the OR operator, so as long as one of shortPutId or shortCallId is non-zero, got reflected here
        uint256 commonId = account.shortPutId | account.shortCallId;

        (, uint32 productId, uint64 expiry, , ) = TokenIdUtil.parseTokenId(commonId);
        detail.productId = productId;
        detail.expiry = expiry;
    }

    /**
     * @dev get a struct that stores all relevent token addresses, along with collateral asset decimals
     */
    function _getProductAssets(uint32 _productId) internal view returns (ProductAssets memory info) {
        (, address underlying, address strike, address collateral, uint8 collatDecimals) = grappa
            .getDetailFromProductId(_productId);
        info.underlying = underlying;
        info.strike = strike;
        info.collateral = collateral;
        info.collateralDecimals = collatDecimals;
    }
}
