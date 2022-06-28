// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {Fixture} from "src/test/shared/Fixture.t.sol";

import "src/config/types.sol";
import "src/config/errors.sol";

contract MarginAccountAccessTest is Fixture {
    uint256 private depositAmount = 100 * 1e6;
    uint64 private strike;

    address private subAccountIdToModify;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(grappa), type(uint256).max);

        subAccountIdToModify = grappa.getSubAccount(alice, 1);
    }

    function testCannotReadSubAccountWithIdTooHigh() public {
        vm.expectRevert(InvalidSubAccountNumber.selector);
        grappa.getSubAccount(address(this), 256);
    }

    function testCannotUpdateRandomAccount() public {
        _assertCanAccessAliceAccount(false);
    }

    function testAliceCanGrantAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), true);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAliceAccount(true);
    }

    function testAliceCanRevokeAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), true);
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAliceAccount(true);
        
        // alice revoke access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), false);
        vm.stopPrank();

        // no longer has access to subaccount!
        _assertCanAccessAliceAccount(false);
    }

    function _assertCanAccessAliceAccount(bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        
        if (!_canAccess) vm.expectRevert(NoAccess.selector);
        
        grappa.execute(subAccountIdToModify, actions);
    }
}
