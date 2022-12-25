// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {TokenIdUtil} from "../../libraries/TokenIdUtil.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

/**
 * @dev tester contract to make coverage works
 */
contract TokenIdUtilTester {
    function getTokenId(TokenType tokenType, uint40 productId, uint64 expiry, uint64 longStrike, uint64 shortStrike)
        external
        pure
        returns (uint256 tokenId)
    {
        uint256 result = TokenIdUtil.getTokenId(tokenType, productId, expiry, longStrike, shortStrike);
        return result;
    }

    function parseCompressedTokenId(uint192 tokenId) external pure returns (TokenType, uint40, uint64, uint64) {
        (TokenType tokenType, uint40 productId, uint64 expiry, uint64 longStrike) = TokenIdUtil.parseCompressedTokenId(tokenId);
        return (tokenType, productId, expiry, longStrike);
    }

    function isExpired(uint256 tokenId) external view returns (bool expired) {
        bool result = TokenIdUtil.isExpired(tokenId);
        return result;
    }

    function compress(uint256 _tokenId) external pure returns (uint192) {
        uint192 result = TokenIdUtil.compress(_tokenId);
        return result;
    }

    function expand(uint192 _tokenId) external pure returns (uint256 newId) {
        uint256 result = TokenIdUtil.expand(_tokenId);
        return result;
    }
}

/**
 * Tests to improve coverage
 */
contract TokenIdLibTest is Test {
    uint256 public constant base = UNIT;

    TokenIdUtilTester tester;

    function setUp() public {
        tester = new TokenIdUtilTester();
    }

    function testCompressAndExpandAreMirrored(uint8 tokenType, uint40 productId, uint256 expiry, uint256 longStrike) public {
        vm.assume(tokenType < 4);
        vm.assume(productId > 0);
        vm.assume(longStrike < type(uint64).max);
        vm.assume(expiry < type(uint64).max);

        // generate an Id without short strike
        uint256 vanillaId = tester.getTokenId(TokenType(tokenType), productId, uint64(expiry), uint64(longStrike), 0);
        uint192 compressedId = tester.compress(vanillaId);

        (TokenType _tokenType, uint40 _productId, uint64 _expiry, uint64 _longStrike) =
            tester.parseCompressedTokenId(compressedId);
        assertEq(uint8(_tokenType), uint8(tokenType));
        assertEq(_productId, productId);
        assertEq(_expiry, expiry);
        assertEq(_longStrike, longStrike);

        uint256 expanded = tester.expand(compressedId);

        assertEq(expanded, vanillaId);
    }

    function testIsExpired() public {
        vm.warp(1671840000);

        uint64 expiry = uint64(block.timestamp + 1);
        uint256 tokenId = tester.getTokenId(TokenType.PUT, 0, expiry, 0, 0);
        assertEq(tester.isExpired(tokenId), false);

        uint64 expiry2 = uint64(block.timestamp - 1);
        uint256 tokenId2 = tester.getTokenId(TokenType.PUT, 0, expiry2, 0, 0);
        assertEq(tester.isExpired(tokenId2), true);
    }
}
