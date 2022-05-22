// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {Fixture} from "./Fixture.t.sol";
import "src/types/MarginAccountTypes.sol";

contract TestAddCollateral is Fixture {
    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);
    }

    function testAddCollateral() public {
        grappa.addCollateral(address(this), address(usdc), 10000 * 1e6);
        (, , , , uint80 _collateralAmount, address _collateral) = grappa
            .marginAccounts(address(this));

        assertEq(_collateral, address(usdc));
        assertEq(_collateralAmount, 10000 * 1e6);
    }
}
