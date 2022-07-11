// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";
import "src/config/errors.sol";

contract OptionTokenTest is Fixture {
    function testCannotMint() public {
        vm.expectRevert(NoAccess.selector);
        option.mint(address(this), 0, 1000_000_000);
    }

    function testCannotBurn() public {
        vm.expectRevert(NoAccess.selector);
        option.burn(address(this), 0, 1000_000_000);
    }

    function testGetUrl() public {
        string memory uri = option.uri(0);
        assertEq(uri, "https://grappa.maybe");
    }
}
