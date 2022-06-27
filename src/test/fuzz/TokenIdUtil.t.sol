// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Test.sol";
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

import "../../config/enums.sol";

contract TokenIdUtilTest is Test {
    function testTokenIdHigherThan0(
        uint8 tokenType,
        uint32 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);

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

        uint256 id = TokenIdUtil.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);
        (TokenType _tokenType, uint32 _productId, uint64 _expiry, uint64 _longStrike, uint64 _shortStrike) = TokenIdUtil
            .parseTokenId(id);

        assertEq(uint8(tokenType), uint8(_tokenType));
        assertEq(productId, _productId);
        assertEq(expiry, _expiry);
        assertEq(longStrike, _longStrike);
        assertEq(shortStrike, _shortStrike);
    }
}
