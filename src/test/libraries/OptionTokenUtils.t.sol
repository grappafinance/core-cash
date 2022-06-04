// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Test.sol";
import {OptionTokenUtils} from "../../libraries/OptionTokenUtils.sol";

import "../../config/enums.sol";

contract OptionTokenUtilsTest is Test {
    function testTokenIdHigherThan0(
        uint8 tokenType,
        uint32 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = OptionTokenUtils.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);

        assertGt(id, 0);
    }

    function testFormatAndParseAreMirrored(
        uint8 tokenType,
        uint32 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = OptionTokenUtils.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);
        (
            TokenType _tokenType,
            uint32 _productId,
            uint64 _expiry,
            uint64 _longStrike,
            uint64 _shortStrike
        ) = OptionTokenUtils.parseTokenId(id);

        assertEq(uint8(tokenType), uint8(_tokenType));
        assertEq(uint32(productId), uint32(_productId));
        assertEq(uint64(expiry), uint64(_expiry));
        assertEq(uint64(longStrike), uint64(_longStrike));
        assertEq(uint64(shortStrike), uint64(_shortStrike));
    }
}
