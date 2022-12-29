// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// imported contracts and libraries
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// librarise
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";

// // constants and types
import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * @title   DebitSpread
 * @author  @dsshap
 * @notice  util functions for MarginEngines to support physically settled options
 */
abstract contract PhysicallySettled is BaseEngine {
    using NumberUtil for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    uint256 constant MIN_SETTLEMENT_WINDOW = 15 minutes;

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint16 public nextIssuerId;

    /// @dev address => issuerId
    mapping(address => uint16) public issuerIds;

    /// @dev issuerId => issuer address
    mapping(uint16 => address) public issuers;

    uint256 public settlementWindow;

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event IssuerRegistered(address subAccount, uint16 id);

    // TODO should settleOption check for aboveWater on subAccount?
    // TODO check that margining math is properly accounting for co-mingled options
    // Change Runs on CME to 10_000
    // TODO account for longDebts in account settled event
    // TODO convert TokenIdUtil.parseTokenId

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev register an issuer for physical options
     * @param _subAccount address of the new margin engine
     */
    function registerIssuer(address _subAccount) public virtual returns (uint16 id) {
        if (issuerIds[_subAccount] != 0) revert PS_IssuerAlreadyRegistered();

        id = ++nextIssuerId;
        issuers[id] = _subAccount;

        issuerIds[_subAccount] = id;

        emit IssuerRegistered(_subAccount, id);
    }

    /**
     * @dev set new settlement window
     * @param _window is the time from expiry that the option can be exercised
     */
    function setPhysicalSettlementWindow(uint256 _window) public virtual {
        if (_window < MIN_SETTLEMENT_WINDOW) revert PS_InvalidSettlementWindow();

        settlementWindow = _window;
    }

    function settlePhysicalOption(Settlement calldata _settlement) public virtual {
        _checkIsGrappa();

        address _subAccount = _getIssuer(_settlement.tokenId);

        // issuer of option gets underlying asset (PUT) or strike asset (CALL)
        _receiveDebtValue(_settlement.debtAssetId, _settlement.debtor, _subAccount, _settlement.debt);

        // option owner gets collateral
        _sendPayoutValue(_settlement.payoutAssetId, _settlement.creditor, _subAccount, _settlement.payout);

        // option burned, removing debt from issuer
        _decreaseShortInAccount(_subAccount, _settlement.tokenId, _settlement.tokenAmount.toUint64());
    }

    /**
     * @dev calculate the payout for one physically settled option token
     * @param _tokenId  token id of option token
     * @return settlement struct
     */
    function getPhysicalSettlementPerToken(uint256 _tokenId) public view virtual returns (Settlement memory settlement) {
        (TokenType tokenType, SettlementType settlementType, uint40 productId, uint64 expiry, uint64 strike,) =
            TokenIdUtil.parseTokenId(_tokenId);

        if (settlementType == SettlementType.CASH) revert PS_InvalidSettlementType();

        // settlement window
        bool settlementWindowOpen = block.timestamp <= expiry + getPhysicalSettlementWindow();

        if (settlementWindowOpen) {
            // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
            uint256 strikePrice = uint256(strike);

            (,, uint8 underlyingId, uint8 strikeId,) = ProductIdUtil.parseProductId(productId);

            // puts can only be collateralized in strike
            (, uint8 strikeDecimals) = grappa.assets(strikeId);
            uint256 strikeAmount = strikePrice.convertDecimals(UNIT_DECIMALS, strikeDecimals);

            // calls can only be collateralized in underlying
            (, uint8 underlyingDecimals) = grappa.assets(underlyingId);
            uint256 underlyingAmount = UNIT.convertDecimals(UNIT_DECIMALS, underlyingDecimals);

            if (tokenType == TokenType.CALL) {
                settlement.debtAssetId = strikeId;
                settlement.debtPerToken = strikeAmount;

                settlement.payoutAssetId = underlyingId;
                settlement.payoutPerToken = underlyingAmount;
            } else if (tokenType == TokenType.PUT) {
                settlement.debtAssetId = underlyingId;
                settlement.debtPerToken = underlyingAmount;

                settlement.payoutAssetId = strikeId;
                settlement.payoutPerToken = strikeAmount;
            }
        }
    }

    function getPhysicalSettlementWindow() public view returns (uint256) {
        return settlementWindow != 0 ? settlementWindow : MIN_SETTLEMENT_WINDOW;
    }

    /*///////////////////////////////////////////////////////////////
                        Override Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev mint option token to _subAccount, checks issuer is properly set
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual override (BaseEngine) {
        // decode tokenId
        uint256 tokenId = abi.decode(_data, (uint256));

        _assertPhysicalSettlementIssuer(_subAccount, tokenId);

        BaseEngine._mintOption(_subAccount, _data);
    }

    /**
     * @dev mint option token into account, increase short position (debt) and increase long position in storage
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual override {
        // decode tokenId
        uint256 tokenId = abi.decode(_data, (uint256));

        _assertPhysicalSettlementIssuer(_subAccount, tokenId);

        BaseEngine._mintOptionIntoAccount(_subAccount, _data);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev ensures issuer is the subAccount
     */
    function _assertPhysicalSettlementIssuer(address _subAccount, uint256 _tokenId) internal view {
        // only check if issuer is properly set if physically settled option
        if (TokenIdUtil.isPhysical(_tokenId)) {
            address issuer = _getIssuer(_tokenId);

            if (issuer != _subAccount) revert PS_InvalidIssuerAddress();
        }
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _assetId asset id to transfer
     * @param _sender sender of debt
     * @param _subAccount receiver
     * @param _amount amount
     */
    function _receiveDebtValue(uint8 _assetId, address _sender, address _subAccount, uint256 _amount) internal {
        (address _asset,) = grappa.assets(_assetId);

        _addCollateralToAccount(_subAccount, _assetId, _amount.toUint80());

        if (_sender != address(this)) IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
    }

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _assetId asset id to transfer
     * @param _recipient receiver of payout
     * @param _subAccount of the sender
     * @param _amount amount
     */
    function _sendPayoutValue(uint8 _assetId, address _recipient, address _subAccount, uint256 _amount) internal {
        (address _asset,) = grappa.assets(_assetId);

        _removeCollateralFromAccount(_subAccount, _assetId, _amount.toUint80());

        if (_recipient != address(this)) IERC20(_asset).safeTransfer(_recipient, _amount);
    }

    function _getIssuer(uint256 _tokenId) internal view returns (address issuer) {
        return issuers[_getIssuerId(_tokenId)];
    }

    function _getIssuerId(uint256 _tokenId) internal pure returns (uint16 issuerId) {
        // since issuer id is uint16 of the last 16 bits of tokenId, we can just cast to uint16
        return uint16(_tokenId);
    }
}
