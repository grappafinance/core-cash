// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixture} from "../engine-integrations/full-margin/FullMarginFixture.t.sol";

import "../../config/types.sol";
import "../../config/errors.sol";

contract AdvancedMarginEngineAccessTest is FullMarginFixture {
    uint256 private depositAmount = 100 * 1e6;

    address private subAccountIdToModify;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        subAccountIdToModify = address(uint160(alice) ^ uint160(1));
    }

    function testCannotUpdateRandomAccount() public {
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function testAliceCanGrantAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), true);
        vm.stopPrank();

        // we can update the account now
        _assertCanAccessAccount(subAccountIdToModify, true);
    }

    function testAliceCanRevokeAccess() public {
        // alice grant access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), true);
        vm.stopPrank();

        // can access subaccount!
        _assertCanAccessAccount(subAccountIdToModify, true);

        // alice revoke access to this contract
        vm.startPrank(alice);
        engine.setAccountAccess(address(this), false);
        vm.stopPrank();

        // no longer has access to subaccount!
        _assertCanAccessAccount(subAccountIdToModify, false);
    }

    function _assertCanAccessAccount(address subAccountId, bool _canAccess) internal {
        // we can update the account now
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);

        if (!_canAccess) vm.expectRevert(NoAccess.selector);

        engine.execute(subAccountId, actions);
    }
}
