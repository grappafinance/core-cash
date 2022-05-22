// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {Fixture} from "./Fixture.t.sol";
import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountConstants.sol";
import "src/constants/MarginAccountEnums.sol";

contract TestAddCollateral is Fixture {
    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);
    }

    function testAddCollateral() public {

        uint256 depositAmount = 1000 * 1e6;

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({
            action: ActionType.AddCollateral,
            // collateral, amount
            data: abi.encode(address(usdc), depositAmount)
        });
        grappa.execute(address(this), actions);
        (, , , , uint80 _collateralAmount, address _collateral) = grappa.marginAccounts(address(this));

        assertEq(_collateral, address(usdc));
        assertEq(_collateralAmount, depositAmount);
    }
}
