// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// imported contracts and libraries
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
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
abstract contract PhysicalSettlement is BaseEngine {
    using FixedPointMathLib for uint256;
    using NumberUtil for uint256;
    using SafeERC20 for IERC20;dddddd
    using TokenIdUtil for uint256;

    /// @dev settlement window will not go below this constant
    uint256 constant MIN_SETTLEMENT_WINDOW = 15 minutes;

    /// @dev window to exercise physical token
    uint256 private _settlementWindow;

    /// @dev token => total
    mapping(uint256 => uint64) public physicalSettlementTokensIssued;

    /// @dev token => count
    mapping(uint256 => uint64) public physicalSettlementTokensExercised;

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice payout to user on settlement.
     * @dev this can only triggered by Grappa, would only be called on settlement.
     * @param _asset asset to transfer
     * @param _sender sender of debt
     * @param _amount amount
     */
    function receiveDebtValue(address _asset, address _sender, uint256 _amount) public virtual {
        _checkIsGrappa();

        if (_sender != address(this)) IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
    }

    /**
     * @dev gets current settlement window
     */
    function settlementWindow() public view returns (uint256) {
        return _settlementWindow != 0 ? _settlementWindow : MIN_SETTLEMENT_WINDOW;
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
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        physicalSettlementTokensIssued[tokenId] += amount;

        BaseEngine._mintOption(_subAccount, _data);
    }

    /**
     * @dev mint option token into account, increase short position (debt) and increase long position in storage
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual override {
        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        physicalSettlementTokensIssued[tokenId] += amount;

        BaseEngine._mintOptionIntoAccount(_subAccount, _data);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _settlePhysicalToken(Settlement calldata _settlement) internal virtual {
        _checkIsGrappa();

        (,,, uint64 expiry,,) = _settlement.tokenId.parseTokenId();
        bool settlementWindowClosed = block.timestamp > expiry + settlementWindow();

        if (settlementWindowClosed) return;

        // incrementing number of exercised token
        physicalSettlementTokensExercised[_settlement.tokenId] += _settlement.tokenAmount;

        // issuer of option gets underlying asset (PUT) or strike asset (CALL)
        (address debtAsset,) = grappa.assets(_settlement.debtAssetId);
        receiveDebtValue(debtAsset, _settlement.debtor, _settlement.debt);

        // option owner gets collateral
        (address payoutAsset,) = grappa.assets(_settlement.payoutAssetId);
        sendPayoutValue(payoutAsset, _settlement.creditor, _settlement.payout);
    }

    /**
     * @dev calculate the payout for one physically settled option token
     * @param _tokenId  token id of option token
     * @return settlement struct
     */
    function _getPhysicalSettlementPerToken(uint256 _tokenId) internal view virtual returns (Settlement memory settlement) {
        (TokenType tokenType,, uint40 productId, uint64 expiry, uint64 strike,) = _tokenId.parseTokenId();

        if (_tokenId.isCash()) revert PS_InvalidSettlementType();

        (,, uint8 underlyingId, uint8 strikeId,) = ProductIdUtil.parseProductId(productId);

        // puts can only be collateralized in strike
        (, uint8 strikeDecimals) = grappa.assets(strikeId);
        uint256 strikeAmount = uint256(strike).convertDecimals(UNIT_DECIMALS, strikeDecimals);

        // calls can only be collateralized in underlying
        (, uint8 underlyingDecimals) = grappa.assets(underlyingId);
        uint256 underlyingAmount = UNIT.convertDecimals(UNIT_DECIMALS, underlyingDecimals);

        // if settlement window closed, return final debts/payouts for short accounts to settle against
        if (block.timestamp >= expiry + settlementWindow()) {
            uint256 issued = uint256(physicalSettlementTokensIssued[_tokenId]);

            if (issued > 0) {
                uint256 exercised = uint256(physicalSettlementTokensExercised[_tokenId]);

                strikeAmount = strikeAmount.mulDivDown(exercised, issued);
                underlyingAmount = underlyingAmount.mulDivDown(exercised, issued);
            } else {
                // No issuance of this particular tokenId
                strikeAmount = 0;
                underlyingAmount = 0;
            }
        }

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

    /**
     * @dev set new settlement window
     * @param _window is the time from expiry that the option can be exercised
     */
    function _setSettlementWindow(uint256 _window) internal virtual {
        if (_window < MIN_SETTLEMENT_WINDOW) revert PS_InvalidSettlementWindow();

        _settlementWindow = _window;
    }
}
