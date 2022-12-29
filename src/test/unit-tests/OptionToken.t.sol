// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {OptionToken} from "../../core/OptionToken.sol";
import {Grappa} from "../../core/Grappa.sol";
import {OptionTokenDescriptor} from "../../core/OptionTokenDescriptor.sol";
import "../../libraries/TokenIdUtil.sol";
import "../../libraries/ProductIdUtil.sol";
import "../../config/errors.sol";

contract OptionTokenTest is Test {
    OptionToken public option;

    address public grappa;
    address public nftDescriptor;

    function setUp() public {
        grappa = address(new Grappa(address(0)));

        nftDescriptor = address(new OptionTokenDescriptor());

        option = new OptionToken(grappa, nftDescriptor);
    }

    function testCannotMint() public {
        uint8 engineId = 1;

        // put in valid tokenId
        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 expiry = block.timestamp + 1 days;
        uint256 tokenId =
            TokenIdUtil.getTokenId(DerivativeType.CALL_SPREAD, SettlementType.CASH, productId, uint64(expiry), 20, 40);

        vm.expectRevert(GP_Not_Authorized_Engine.selector);
        option.mint(address(this), tokenId, 1000_000_000);
    }

    function testCannotBurn() public {
        vm.expectRevert(GP_Not_Authorized_Engine.selector);
        option.burn(address(this), 0, 1000_000_000);
    }

    function testCannotBurnGrappaOnly() public {
        vm.expectRevert(NoAccess.selector);
        option.burnGrappaOnly(address(this), 0, 1000_000_000);

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        vm.expectRevert(NoAccess.selector);
        option.batchBurnGrappaOnly(address(this), ids, amounts);
    }

    function testCannotMintCreditCallSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId =
            TokenIdUtil.getTokenId(DerivativeType.CALL_SPREAD, SettlementType.CASH, productId, uint64(expiry), 40, 20);

        vm.expectRevert(GP_BadCashSettledStrikes.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintPhysicallySettledCreditCallSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId =
            TokenIdUtil.getTokenId(DerivativeType.CALL_SPREAD, SettlementType.PHYSICAL, productId, uint64(expiry), 40, 1);

        vm.expectRevert(GP_BadPhysicallySettledDerivative.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintCreditPutSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId =
            TokenIdUtil.getTokenId(DerivativeType.PUT_SPREAD, SettlementType.CASH, productId, uint64(expiry), 20, 40);

        vm.expectRevert(GP_BadCashSettledStrikes.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintPhysicallySettledCreditPutSpread() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId =
            TokenIdUtil.getTokenId(DerivativeType.PUT_SPREAD, SettlementType.PHYSICAL, productId, uint64(expiry), 20, 1);

        vm.expectRevert(GP_BadPhysicallySettledDerivative.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintCallWithShortStrike() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(DerivativeType.CALL, SettlementType.CASH, productId, uint64(expiry), 20, 40);

        vm.expectRevert(GP_BadCashSettledStrikes.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintPutWithShortStrike() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(DerivativeType.PUT, SettlementType.CASH, productId, uint64(expiry), 20, 40);

        vm.expectRevert(GP_BadCashSettledStrikes.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintPhysicallySettledPutWithNoIssuer() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(DerivativeType.PUT, SettlementType.PHYSICAL, productId, uint64(expiry), 20, 0);

        vm.expectRevert(GP_BadPhysicallySettledDerivative.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testCannotMintPhysicallySettledCallWithNoIssuer() public {
        uint8 engineId = 1;
        uint256 expiry = block.timestamp + 1 days;

        vm.mockCall(grappa, abi.encodeWithSelector(Grappa(grappa).engines.selector, engineId), abi.encode(address(this)));

        uint40 productId = ProductIdUtil.getProductId(0, engineId, 0, 0, 0);
        uint256 tokenId = TokenIdUtil.getTokenId(DerivativeType.CALL, SettlementType.PHYSICAL, productId, uint64(expiry), 40, 0);

        vm.expectRevert(GP_BadPhysicallySettledDerivative.selector);
        option.mint(address(this), tokenId, 1);
    }

    function testGetUrl() public {
        assertEq(option.uri(0), "https://grappa.finance/token/0");

        assertEq(option.uri(200), "https://grappa.finance/token/200");
    }
}
