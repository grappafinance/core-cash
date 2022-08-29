// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../shared/AdvancedFixture.t.sol";

import "../../config/errors.sol";

contract OptionTokenTest is AdvancedFixture {
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
