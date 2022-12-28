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
import "../../../config/types.sol";

/**
 * @title   DebitSpread
 * @author  @dsshap
 * @notice  util functions for MarginEngines to support physically settled derivatives
 */
abstract contract PhysicallySettled is BaseEngine {
    using NumberUtil for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /// @dev next id used to represent an address
    /// invariant:  any id in tokenId not greater than this number
    uint16 public nextIssuerId;

    /// @dev address => issuerId
    mapping(address => uint16) public issuerIds;

    mapping(uint16 => address) public issuers;

    error PS_IssuerAlreadyRegistered();

    event IssuerRegistered(address subAccount, uint16 id);

    // TODO add set settlementWindow function
    // TODO enforce _mintOption to include issuer id (for force)
    // TODO should settleOption check for aboveWater on subAccount?
    // TODO CM.getDebtAndPayoutPerToken revert ERROR
    // TODO CMLib settle shorts and longs

    /**
     * @dev register an issuer for physical options
     * @param _subAccount address of the new margin engine
     *
     */
    function registerIssuer(address _subAccount) public virtual returns (uint16 id) {
        if (issuerIds[_subAccount] != 0) revert PS_IssuerAlreadyRegistered();

        id = ++nextIssuerId;
        issuers[id] = _subAccount;

        issuerIds[_subAccount] = id;

        emit IssuerRegistered(_subAccount, id);
    }

    function physicallySettleOption(Settlement calldata _settlement) public virtual {
        _checkIsGrappa();

        address _subAccount = issuers[uint16(_settlement.tokenId)];

        _receiveDebtValue(_settlement.debtAssetId, _settlement.debtor, _subAccount, _settlement.debt);

        _sendPayoutValue(_settlement.payoutAssetId, _settlement.creditor, _subAccount, _settlement.payout);

        _decreaseShortInAccount(_subAccount, _settlement.tokenId, _settlement.tokenAmount.toUint64());
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

    /**
     * @dev calculate the payout for one physically settled derivative token
     * @param _tokenId  token id of derivative token
     * @return settlement struct
     */
    function _getDebtAndPayoutPerToken(uint256 _tokenId) internal view virtual returns (Settlement memory settlement) {
        (DerivativeType derivativeType,, uint40 productId, uint64 expiry, uint64 strike,) = TokenIdUtil.parseTokenId(_tokenId);

        // settlement window
        bool settlementWindowOpen = block.timestamp < expiry + 1 hours;

        if (settlementWindowOpen) {
            // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
            uint256 strikePrice = uint256(strike);

            (,, uint8 underlyingId, uint8 strikeId, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

            (, uint8 strikeDecimals) = grappa.assets(strikeId);
            uint256 strikeAmount = strikePrice.convertDecimals(UNIT_DECIMALS, strikeDecimals);

            if (derivativeType == DerivativeType.CALL) {
                settlement.debtAssetId = strikeId;
                settlement.debtPerToken = strikeAmount;

                settlement.payoutAssetId = collateralId;
                (, uint8 collateralDecimals) = grappa.assets(collateralId);
                settlement.payoutPerToken = UNIT.convertDecimals(UNIT_DECIMALS, collateralDecimals);
            } else if (derivativeType == DerivativeType.PUT) {
                settlement.debtAssetId = underlyingId;
                (, uint8 underlyingDecimals) = grappa.assets(underlyingId);
                settlement.debtPerToken = UNIT.convertDecimals(UNIT_DECIMALS, underlyingDecimals);

                settlement.payoutAssetId = strikeId;
                settlement.payoutPerToken = strikeAmount;
            }
        }
    }
}
