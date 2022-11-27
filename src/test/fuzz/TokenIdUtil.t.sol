// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";

import "../../config/enums.sol";

contract TokenIdUtilTest is Test {
    function testTokenIdHigherThan0(uint8 tokenType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike) public {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);

        assertGt(id, 0);
    }

    function testFormatAndParseAreMirrored(uint8 tokenType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike)
        public
    {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.formatTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);
        (TokenType _tokenType, uint40 _productId, uint64 _expiry, uint64 _longStrike, uint64 _shortStrike) = TokenIdUtil.parseTokenId(id);

        assertEq(uint8(tokenType), uint8(_tokenType));
        assertEq(productId, _productId);
        assertEq(expiry, _expiry);
        assertEq(longStrike, _longStrike);
        assertEq(shortStrike, _shortStrike);
    }

    function testGetAndParseAreMirrored(uint8 tokenType, uint40 productId, uint256 expiry, uint256 longStrike, uint256 shortStrike)
        public
    {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);

        uint256 id = TokenIdUtil.getTokenId(TokenType(tokenType), productId, expiry, longStrike, shortStrike);
        (TokenType _tokenType, uint40 _productId, uint64 _expiry, uint64 _longStrike, uint64 _shortStrike) = TokenIdUtil.parseTokenId(id);

        assertEq(tokenType, uint8(_tokenType));
        assertEq(productId, _productId);
        assertEq(uint64(expiry), _expiry);
        assertEq(uint64(longStrike), _longStrike);
        assertEq(uint64(shortStrike), _shortStrike);
    }
}
