// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {OptionToken} from "../../core/OptionToken.sol";
import {Grappa} from "../../core/Grappa.sol";
import "../../libraries/TokenIdUtil.sol";
import "../../libraries/ProductIdUtil.sol";
import "../../config/errors.sol";

contract OptionTokenTest is Test {
    OptionToken public option;

    address public grappa;

    function setUp() public {
        grappa = address(new Grappa(address(0)));
        option = new OptionToken(grappa);
    }

    function testCannotMint() public {
        vm.expectRevert(OT_Not_Authorized_Engine.selector);
        option.mint(address(this), 0, 1000_000_000);
    }

    function testCannotBurn() public {
        vm.expectRevert(OT_Not_Authorized_Engine.selector);
        option.burn(address(this), 0, 1000_000_000);
    }

    function testCannotBurnGrappaOnly() public {
        vm.expectRevert(NoAccess.selector);
        option.burnGrappaOnly(address(this), 0, 1000_000_000);

        uint256[] memory ids = new uint[](0);
        uint256[] memory amounts = new uint[](0);
        vm.expectRevert(NoAccess.selector);
        option.batchBurnGrappaOnly(address(this), ids, amounts);
    }

    function testCannotMintCreditCallSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(
            grappa, 
            abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), 
            abi.encode(address(this))
        );

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL_SPREAD, productId, expiry, 40, 20);

        vm.expectRevert(OT_BadStrikes.selector);
        option.mint(address(this), tokenId, 1);   
    }

    function testCannotMintCreditPutSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(
            grappa, 
            abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), 
            abi.encode(address(this))
        );

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.PUT_SPREAD, productId, expiry, 20, 40);

        vm.expectRevert(OT_BadStrikes.selector);
        option.mint(address(this), tokenId, 1);   
    }

    function testCannotMintCallWithShortStrike() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(
            grappa, 
            abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), 
            abi.encode(address(this))
        );

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.CALL, productId, expiry, 20, 40);

        vm.expectRevert(OT_BadStrikes.selector);
        option.mint(address(this), tokenId, 1);   
    }

    function testCannotMintPutWithShortStrike() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(
            grappa, 
            abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), 
            abi.encode(address(this))
        );

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(TokenType.PUT, productId, expiry, 20, 40);

        vm.expectRevert(OT_BadStrikes.selector);
        option.mint(address(this), tokenId, 1);   
    }

    function testGetUrl() public {
        string memory uri = option.uri(0);
        assertEq(uri, "https://grappa.maybe");
    }
}
