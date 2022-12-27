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
    function getDebtAndPayoutPerToken(uint256 _tokenId)
        public
        view
        virtual
        returns (address issuer, uint256 debtPerToken, uint256 payoutPerToken)
    {
        (DerivativeType derivativeType,, uint40 productId, uint64 expiry, uint64 strikePrice,) =
            TokenIdUtil.parseTokenId(_tokenId);

        (,, uint8 underlyingId,, uint8 collateralId) = ProductIdUtil.parseProductId(productId);

        (, uint8 collateralDecimals) = grappa.assets(collateralId);

        // settlement window
        bool settlementWindowOpen = block.timestamp < expiry + 1 hours;

        // cash value denominated in strike (usually USD), with {UNIT_DECIMALS} decimals
        uint256 cashValue;

        if (derivativeType == DerivativeType.PUT && settlementWindowOpen) {
            (, uint8 underlyingDecimals) = grappa.assets(underlyingId);

            debtPerToken = UNIT.convertDecimals(UNIT_DECIMALS, underlyingDecimals);

            cashValue = strikePrice;
        }

        payoutPerToken = cashValue.convertDecimals(UNIT_DECIMALS, collateralDecimals);
    }
}
