// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

import "../../config/enums.sol";

contract TokenIdUtilTest is Test {
    function testTokenIdHigherThan0(
        uint8 derivativeType,
        uint8 settlementType,
        uint40 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        vm.assume(derivativeType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(
            DerivativeType(derivativeType), SettlementType(settlementType), productId, expiry, longStrike, shortStrike
        );

        assertGt(id, 0);
    }

    function testFormatAndParseAreMirrored(
        uint8 derivativeType,
        uint8 settlementType,
        uint40 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        vm.assume(derivativeType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(
            DerivativeType(derivativeType), SettlementType(settlementType), productId, expiry, longStrike, shortStrike
        );
        (
            DerivativeType _derivativeType,
            SettlementType _settlementType,
            uint40 _productId,
            uint64 _expiry,
            uint64 _longStrike,
            uint64 _shortStrike
        ) = TokenIdUtil.parseTokenId(id);

        assertEq(uint8(derivativeType), uint8(_derivativeType));
        assertEq(uint8(settlementType), uint8(_settlementType));
        assertEq(productId, _productId);
        assertEq(expiry, _expiry);
        assertEq(longStrike, _longStrike);
        assertEq(shortStrike, _shortStrike);
    }

    function testGetAndParseAreMirrored(
        uint8 derivativeType,
        uint8 settlementType,
        uint40 productId,
        uint256 expiry,
        uint256 longStrike,
        uint256 shortStrike
    ) public {
        vm.assume(derivativeType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(
            DerivativeType(derivativeType),
            SettlementType(settlementType),
            productId,
            uint64(expiry),
            uint64(longStrike),
            uint64(shortStrike)
        );
        (
            DerivativeType _derivativeType,
            SettlementType _settlementType,
            uint40 _productId,
            uint64 _expiry,
            uint64 _longStrike,
            uint64 _shortStrike
        ) = TokenIdUtil.parseTokenId(id);

        assertEq(derivativeType, uint8(_derivativeType));
        assertEq(settlementType, uint8(_settlementType));
        assertEq(productId, _productId);
        assertEq(uint64(expiry), _expiry);
        assertEq(uint64(longStrike), _longStrike);
        assertEq(uint64(shortStrike), _shortStrike);
    }
}
