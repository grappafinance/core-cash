// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// librarise
import {ProductIdUtil} from "../../../libraries/ProductIdUtil.sol";
import {TokenIdUtil} from "../../../libraries/TokenIdUtil.sol";
import {NumberUtil} from "../../../libraries/NumberUtil.sol";

// // constants and types
import "../../../config/constants.sol";
import "../../../config/enums.sol";

/**
 * @title   DebitSpread
 * @author  @dsshap
 * @notice  util functions for MarginEngines to support physically settled derivatives
 */
abstract contract PhysicallySettled is BaseEngine {
    using NumberUtil for uint256;

    /**
     * @dev calculate the payout for one physically settled derivative token
     * @param _tokenId  token id of derivative token
     * @return issuer minted derivative
     * @return debtPerToken amount owed
     * @return payoutPerToken amount paid
     */
    function _getDebtAndPayoutPerToken(uint256 _tokenId)
        internal
        view
        virtual
        returns (address issuer, uint256 debtPerToken, uint256 payoutPerToken)
    {
        (DerivativeType derivativeType,, uint40 productId, uint64 expiry, uint64 strike,) = TokenIdUtil.parseTokenId(_tokenId);

        // settlement window
        bool settlementWindowOpen = block.timestamp < expiry + 1 hours;

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals

        if (settlementWindowOpen) {
            uint256 strikePrice = uint256(strike);

            (,, uint8 underlyingId,, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

            (, uint8 underlyingDecimals) = grappa.assets(underlyingId);
            (, uint8 collateralDecimals) = grappa.assets(collateralId);

            uint256 numeraire = strikePrice.convertDecimals(UNIT_DECIMALS, collateralDecimals);
            uint256 underlying = UNIT.convertDecimals(UNIT_DECIMALS, underlyingDecimals);

            if (derivativeType == DerivativeType.CALL) {
                debtPerToken = numeraire;

                payoutPerToken = underlying;
            } else if (derivativeType == DerivativeType.PUT) {
                debtPerToken = underlying;

                payoutPerToken = numeraire;
            }
        }
    }
}
