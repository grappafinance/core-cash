// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "../../engine-integrations/cross-margin/CrossMarginFixture.t.sol";

import "../../../config/types.sol";
import "../../../config/errors.sol";

contract CrossMarginEngineAccessTest is CrossMarginFixture {
    uint256 private depositAmount = 100 * 1e6;

    address private subAccountIdToModify;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        usdc.mint(alice, 1000_000 * 1e6);

        vm.startPrank(alice);
        usdc.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        subAccountIdToModify = address(uint160(alice) ^ uint160(1));

        vm.startPrank(alice);
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, alice, depositAmount);
        engine.execute(subAccountIdToModify, actions);
        vm.stopPrank();
    }

    function testTransferCMAccount() public {
        vm.startPrank(alice);
        engine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(address(this), true);

        (,, Balance[] memory collaterals) = engine.marginAccounts(address(this));

        assertEq(collaterals.length, 1);
        assertEq(collaterals[0].collateralId, usdcId);
        assertEq(collaterals[0].amount, depositAmount * 2);
    }

    function testCannotTransferUnAuthorizedAccount() public {
        vm.expectRevert(NoAccess.selector);
        engine.transferAccount(alice, address(this));
    }

    function testCannotTransferToOverrideAnotherAccount() public {
        // write something to account "address(this)"
        _assertCanAccessAccount(address(this), true);

        vm.startPrank(alice);
        vm.expectRevert(CM_AccountIsNotEmpty.selector);
        engine.transferAccount(subAccountIdToModify, address(this));
        vm.stopPrank();
    }

    function _assertCanAccessAccount(address subAccountId, bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);

        if (!_canAccess) vm.expectRevert(NoAccess.selector);

        engine.execute(subAccountId, actions);
    }
}
