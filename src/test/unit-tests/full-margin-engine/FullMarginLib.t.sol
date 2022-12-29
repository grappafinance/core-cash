// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import {FullMarginLib} from "../../../core/engines/full-margin/FullMarginLib.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/full-margin/types.sol";

/**
 * @dev forge coverage only pick up coverage for internal libraries
 *      when it's initiated with external calls
 */
contract FullMarginLibTester {
    using FullMarginLib for FullMarginAccount;

    FullMarginAccount private _account;

    function account() external view returns (FullMarginAccount memory) {
      return _account;
    }

    function isEmpty() external view returns (bool) {
        bool empty = FullMarginLib.isEmpty(_account);
        return empty;
    }

    function addCollateral(uint8 collateralId, uint80 amount) external {
        FullMarginLib.addCollateral(_account, collateralId, amount);
    }

    function removeCollateral(uint8 collateralId, uint80 amount) external {
        FullMarginLib.removeCollateral(_account, collateralId, amount);
    }

    function mintOption(uint256 tokenId, uint64 amount) external {
        FullMarginLib.mintOption(_account, tokenId, amount);
    }

    function burnOption(uint256 tokenId, uint64 amount) external {
        FullMarginLib.burnOption(_account, tokenId, amount);
    }

    function merge(uint256 shortId, uint256 longId, uint64 amount) external {
        FullMarginLib.merge(_account, shortId, longId, amount);
    }

    function split(uint256 spreadId, uint64 amount) external {
        FullMarginLib.split(_account, spreadId, amount);
    }

    function settleAtExpiry(uint80 payout) external {
        FullMarginLib.settleAtExpiry(_account, payout);
    }
}

/**
 * test full margin calculation for simple call
 */
contract FullMarginLibTest is Test {
    
    FullMarginLibTester tester;

    function setUp() public {
        tester = new FullMarginLibTester();
    }

    function testIsEmpty() public {
        bool isEmpty = tester.isEmpty();
        assertEq(isEmpty, true);
    }

    function testAddCollateral() public {
        uint8 collatId = 1;
        tester.addCollateral(collatId, 100);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.collateralId, collatId);

        // can add the same collaterl id again
        tester.addCollateral(collatId, 100);
        acc = tester.account();
        assertEq(acc.collateralId, collatId);
        assertEq(acc.collateralAmount, 200);

        // cannot add collateral with diff id
        vm.expectRevert(FM_WrongCollateralId.selector);
        tester.addCollateral(collatId + 1, 100);
    }

    function testCanAddZeroId() public {
        // the storage library won't revert if 0 is specified
        // Engine contract needs to make sure collateral id cannot be 0
        tester.addCollateral(0, 100);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.collateralId, 0);
        assertEq(acc.collateralAmount, 100);
    }

    function testReduceCollateral() public {
        uint80 collatAmount = 100;
        uint8 collatId = 1;
        tester.addCollateral(collatId, collatAmount);

        // cannot remove a diff collateral id
        vm.expectRevert(FM_WrongCollateralId.selector);
        tester.removeCollateral(collatId + 1, collatAmount);

        // can only remove half
        tester.removeCollateral(collatId, collatAmount / 2);
        FullMarginAccount memory acc = tester.account();
        assertEq(acc.collateralId, collatId);
        assertEq(acc.collateralAmount, collatAmount / 2);

        // cannot remove more then the acconut holds
        vm.expectRevert(stdError.arithmeticError);
        tester.removeCollateral(collatId, acc.collateralAmount + 1);

        // can remove all
        tester.removeCollateral(collatId, acc.collateralAmount);
        acc = tester.account();
        assertEq(acc.collateralId, 0);
        assertEq(acc.collateralAmount, 0);

    }
    
}
