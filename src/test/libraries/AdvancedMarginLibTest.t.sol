// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Test} from "forge-std/Test.sol";

import {AdvancedMarginLib} from "../../core/engines/libraries/AdvancedMarginLib.sol";
import "../../config/constants.sol";
import "../../config/errors.sol";
import "../../config/types.sol";

import "forge-std/console2.sol";

/**
 * Test for the AdvancedMarginLib that update account storage
 */
contract AdvancedMarginLibTest is Test {
    using AdvancedMarginLib for Account;

    Account public emptyAccount;
    Account public nonEmptyAccount;

    uint8 public collateralId1 = 1;
    uint8 public collateralId2 = 2;

    uint80 public amount = uint80(UNIT);

    function setUp() public {
        nonEmptyAccount.addCollateral(amount, collateralId1);
    }

    function testAddCollateral() public {
        emptyAccount.addCollateral(amount, collateralId1);

        assertEq(emptyAccount.collateralId, collateralId1);
        assertEq(emptyAccount.collateralAmount, amount);
    }

    function testCannotAddDiffCollateral() public {
        vm.expectRevert(AM_WrongCollateralId.selector);
        nonEmptyAccount.addCollateral(amount, collateralId2);
    }

    function testRemoveHalfCollateral() public {
        nonEmptyAccount.removeCollateral((amount / 2), collateralId1);
        assertEq(nonEmptyAccount.collateralId, collateralId1);
        assertEq(nonEmptyAccount.collateralAmount, (amount / 2));
    }

    function testRemoveAllCollateral() public {
        nonEmptyAccount.removeCollateral(amount, collateralId1);
        assertEq(emptyAccount.collateralId, 0);
        assertEq(emptyAccount.collateralAmount, 0);
    }
}
