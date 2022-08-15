// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {AdvancedFixture} from "../shared/AdvancedFixture.t.sol";

import "../../config/types.sol";
import "../../config/errors.sol";

contract AdvancedMarginEngineAccessTest is AdvancedFixture {
    uint256 private depositAmount = 100 * 1e6;

    address private subAccountIdToModify;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(marginEngine), type(uint256).max);

        subAccountIdToModify = address(uint160(alice) ^ uint160(1));
    }

    function testCannotUpdateRandomAccount() public {
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testAliceCanGrantAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), true);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAccount(subAccountIdToModify, true);
    }

    function testAliceCanRevokeAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), true);
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(subAccountIdToModify, true);

        // alice revoke access to this contract
        vm.startPrank(alice);
        grappa.setAccountAccess(address(this), false);
        vm.stopPrank();

        // no longer has access to subaccount!
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testTransferAccount() public {
        vm.startPrank(alice);
        marginEngine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(address(this), true);
    }

    function testCannotTransferToOverrideAnotherAccount() public {
        // write something to account "address(this)"
        _assertCanAccessAccount(address(this), true);

        vm.startPrank(alice);
        vm.expectRevert(MA_AccountIsNotEmpty.selector);
        marginEngine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();
    }

    function _assertCanAccessAccount(address subAccountId, bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);

        if (!_canAccess) vm.expectRevert(NoAccess.selector);

        grappa.execute(engineId, subAccountId, actions);
    }
}
