// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

import "../../config/enums.sol";

contract TokenIdUtilTest is Test {
    function testTokenIdHigherThan0(
        uint8 tokenType,
        uint8 settlementType,
        uint40 productId,
        uint64 expiry,
        uint64 strike,
        uint64 reserved
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id =
            TokenIdUtil.getTokenId(TokenType(tokenType), SettlementType(settlementType), productId, expiry, strike, reserved);

        assertGt(id, 0);
    }

    function testFormatAndParseAreMirrored(
        uint8 tokenType,
        uint8 settlementType,
        uint40 productId,
        uint64 expiry,
        uint64 strike,
        uint64 reserved
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id =
            TokenIdUtil.getTokenId(TokenType(tokenType), SettlementType(settlementType), productId, expiry, strike, reserved);
        (
            TokenType _optionType,
            SettlementType _settlementType,
            uint40 _productId,
            uint64 _expiry,
            uint64 _strike,
            uint64 _reserved
        ) = TokenIdUtil.parseTokenId(id);

        assertEq(uint8(tokenType), uint8(_optionType));
        assertEq(uint8(settlementType), uint8(_settlementType));
        assertEq(productId, _productId);
        assertEq(expiry, _expiry);
        assertEq(strike, _strike);
        assertEq(reserved, _reserved);
    }

    function testGetAndParseAreMirrored(
        uint8 tokenType,
        uint8 settlementType,
        uint40 productId,
        uint256 expiry,
        uint256 strike,
        uint256 reserved
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(settlementType < 2);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(
            TokenType(tokenType), SettlementType(settlementType), productId, uint64(expiry), uint64(strike), uint64(reserved)
        );
        (
            TokenType _optionType,
            SettlementType _settlementType,
            uint40 _productId,
            uint64 _expiry,
            uint64 _strike,
            uint64 _reserved
        ) = TokenIdUtil.parseTokenId(id);

        assertEq(tokenType, uint8(_optionType));
        assertEq(settlementType, uint8(_settlementType));
        assertEq(productId, _productId);
        assertEq(uint64(expiry), _expiry);
        assertEq(uint64(strike), _strike);
        assertEq(uint64(reserved), _reserved);
    }
}
