// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";

import {AdvancedMarginLib} from "../../../core/engines/advanced-margin/AdvancedMarginLib.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

import "forge-std/console2.sol";

/**
 * Test for the AdvancedMarginLib that update account storage
 */
contract AdvancedMarginLibTest is Test {
    using AdvancedMarginLib for Account;

    uint8 public collateralId1 = 1;
    uint8 public collateralId2 = 2;

    uint80 public amount = uint80(UNIT);

    function testAddCollateral() public {
        Account memory account;
        account.addCollateral(amount, collateralId1);

        assertEq(account.collateralId, collateralId1);
        assertEq(account.collateralAmount, amount);
    }

    function testCannotAddDiffCollateral() public {
        Account memory account;
        account.addCollateral(amount, collateralId1);

        vm.expectRevert(AM_WrongCollateralId.selector);
        account.addCollateral(amount, collateralId2);
    }

    function testRemoveHalfCollateral() public {
        Account memory account;
        account.addCollateral(amount, collateralId1);

        account.removeCollateral((amount / 2), collateralId1);
        assertEq(account.collateralId, collateralId1);
        assertEq(account.collateralAmount, (amount / 2));
    }

    function testRemoveAllCollateral() public {
        Account memory account;
        account.addCollateral(amount, collateralId1);

        account.removeCollateral(amount, collateralId1);
        assertEq(account.collateralId, 0);
        assertEq(account.collateralAmount, 0);
    }
}
