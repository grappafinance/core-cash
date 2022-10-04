// SPDX-License-Identifier: MIT
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
import {ArrayUtil} from "../../../libraries/ArrayUtil.sol";

import {FullMarginMathV2} from "./FullMarginMathV2.sol";
import {FullMarginLibV2} from "./FullMarginLibV2.sol";

// constants and types
import "../../../config/types.sol";
import "../../../config/enums.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

/**
 * @title   FullMarginEngine
 * @author  @dsshap & @antoncoding
 * @notice  Fully collateralized margin engine
            Users can deposit collateral into FullMargin and mint optionTokens (debt) out of it.
            Interacts with OptionToken to mint / burn
            Interacts with grappa to fetch registered asset info
 */
contract FullMarginEngineV2 is BaseEngine, IMarginEngine {
    using ArrayUtil for bytes32[];
    using ArrayUtil for uint8[];
    using ArrayUtil for uint64[];
    using ArrayUtil for uint80[];
    using ArrayUtil for int256[];
    using ArrayUtil for uint256[];
    using FullMarginLibV2 for FullMarginAccountV2;
    using FullMarginMathV2 for FullMarginDetailV2;
    using SafeCast for uint64;
    using SafeCast for uint256;
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

    function execute(address _subAccount, ActionArgs[] calldata actions) public override nonReentrant {
        _assertCallerHasAccess(_subAccount);

        // update the account memory and do external calls on the flight
        for (uint256 i; i < actions.length; ) {
            if (actions[i].action == ActionType.AddCollateral) _addCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.RemoveCollateral) _removeCollateral(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.MintShort) _mintOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.BurnShort) _burnOption(_subAccount, actions[i].data);
            else if (actions[i].action == ActionType.SettleAccount) _settle(_subAccount);
            else revert FM_UnsupportedAction();

            // increase i without checking overflow
            unchecked {
                i++;
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
     * @return collaterals array of collaterals
     * @return amounts array of amounts
     */
    function getMinCollateral(address _subAccount)
        external
        view
        returns (uint8[] memory collaterals, int256[] memory amounts)
    {
        FullMarginAccountV2 memory account = accounts[_subAccount];
        (collaterals, amounts) = _getMinCollateral(account);
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
            uint256[] memory shorts,
            uint64[] memory shortAmounts,
            uint256[] memory longs,
            uint64[] memory longAmounts,
            uint8[] memory collaterals,
            uint80[] memory collateralAmounts
        )
    {
        FullMarginAccountV2 memory account = accounts[_subAccount];

        return (
            account.shorts,
            account.shortAmounts,
            account.longs,
            account.longAmounts,
            account.collaterals,
            account.collateralAmounts
        );
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

    function _settleAccount(address _subAccount, uint80 payout) internal override {
        accounts[_subAccount].settleAtExpiry(payout);
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
        (, int256[] memory collateralAmounts) = _getMinCollateral(account);

        for (uint256 i = 0; i < collateralAmounts.length; i++) {
            if (collateralAmounts[i] < 0) return false;
        }

        return true;
    }

    /**
     * @notice  return amount of collateral that should be reserved to payout long positions
     * @dev     this function will revert when called before expiry
     * @param _subAccount account id
     */
    function _getAccountPayout(address _subAccount) internal view override returns (uint80) {
        // FullMarginAccountV2 memory account = accounts[_subAccount];
        // (, , uint256 payout) = grappa.getPayout(account.tokenId, account.shortAmount);
        // return payout.toUint80();
        return 0;
    }

    /** ========================================================= **
                            Internal Functions
     ** ========================================================= **/

    function _getMinCollateral(FullMarginAccountV2 memory account)
        internal
        view
        returns (uint8[] memory collaterals, int256[] memory collateralAmounts)
    {
        FullMarginDetailV2[] memory details = _getAccountDetails(account);

        collaterals = account.collaterals;
        collateralAmounts = account.collateralAmounts.toInt256();

        if (details.length == 0) return (collaterals, collateralAmounts);

        bool found;
        uint256 index;

        for (uint256 i = 0; i < details.length; i++) {
            FullMarginDetailV2 memory detail = details[i];

            (int256 cashCollateralNeeded, int256 underlyingNeeded) = detail.getMinCollateral();

            if (cashCollateralNeeded > 0) {
                (found, index) = collaterals.indexOf(detail.collateralId);
                if (found) collateralAmounts[index] -= cashCollateralNeeded;
                else {
                    collaterals = collaterals.append(detail.collateralId);
                    collateralAmounts = collateralAmounts.append(-cashCollateralNeeded);
                }
            }

            if (underlyingNeeded > 0) {
                (found, index) = collaterals.indexOf(detail.underlyingId);
                if (found) collateralAmounts[index] -= underlyingNeeded;
                else {
                    collaterals = collaterals.append(detail.underlyingId);
                    collateralAmounts = collateralAmounts.append(-underlyingNeeded);
                }
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

        bytes32[] memory uceLookUp = new bytes32[](0);

        uint256[] memory tokenIds = account.shorts.concat(account.longs);
        uint64[] memory tokenAmounts = account.shortAmounts.concat(account.longAmounts);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            (, uint40 productId, uint64 expiry, , ) = tokenIds[i].parseTokenId();

            ProductDetails memory product = _getProductDetails(productId);

            FullMarginDetailV2 memory detail;

            bytes32 pos = keccak256(abi.encode(product.underlyingId, product.collateralId, expiry));
            (bool found, uint256 index) = uceLookUp.indexOf(pos);

            if (found) detail = details[index];
            else {
                uceLookUp = uceLookUp.append(pos);
                details = _appendDetail(details, detail);

                detail.underlyingId = product.underlyingId;
                detail.underlyingDecimals = product.underlyingDecimals;
                detail.collateralId = product.collateralId;
                detail.collateralDecimals = product.collateralDecimals;
                detail.spotPrice = IOracle(product.oracle).getSpotPrice(product.underlying, product.strike);
                detail.expiry = expiry;
            }

            int256 amount = tokenAmounts[i].toInt256();
            if (i < account.shorts.length) amount = -amount;

            _processDetailWithToken(detail, tokenIds[i], amount);
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
            if (found) detail.callWeights[index] += amount;
            else {
                detail.callStrikes = detail.callStrikes.append(longStrike);
                detail.callWeights = detail.callWeights.append(amount);
            }
        }

        if (tokenType == TokenType.PUT) {
            (found, index) = detail.putStrikes.indexOf(longStrike);
            if (found) detail.putWeights[index] += amount;
            else {
                detail.putStrikes = detail.putStrikes.append(longStrike);
                detail.putWeights = detail.putWeights.append(amount);
            }
        }
    }

    function _appendDetail(FullMarginDetailV2[] memory array, FullMarginDetailV2 memory detail)
        internal
        pure
        returns (FullMarginDetailV2[] memory details)
    {
        details = new FullMarginDetailV2[](array.length + 1);
        uint256 i;
        for (i = 0; i < array.length; i++) {
            details[i] = array[i];
        }
        details[i] = detail;
    }

    function _getProductDetails(uint40 _productId) internal view returns (ProductDetails memory info) {
        (, , uint8 underlyingId, , uint8 collateralId) = ProductIdUtil.parseProductId(_productId);

        (
            address oracle,
            ,
            address underlying,
            uint8 underlyingDecimals,
            address strike,
            ,
            address collateral,
            uint8 collatDecimals
        ) = grappa.getDetailFromProductId(_productId);

        info.oracle = oracle;
        info.underlying = underlying;
        info.underlyingDecimals = underlyingDecimals;
        info.strike = strike;
        info.collateral = collateral;
        info.collateralDecimals = collatDecimals;
        info.underlyingId = underlyingId;
        info.collateralId = collateralId;
    }
}
