// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {OptionToken} from "../../core/OptionToken.sol";
import {Grappa} from "../../core/Grappa.sol";
import "forge-std/Test.sol";
import "../../config/errors.sol";

contract OptionTokenTest is Test {
    OptionToken public option;

    address public grappa;

    function setUp() public {
        grappa = address(new Grappa(address(0), address(0)));
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

    function testGetUrl() public {
        string memory uri = option.uri(0);
        assertEq(uri, "https://grappa.maybe");
    }
}
