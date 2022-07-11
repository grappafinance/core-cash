// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base.
import {Fixture} from "src/test/shared/Fixture.t.sol";

import "src/config/constants.sol";

contract OwnerConfiguration is Fixture {
    function testSettingConfigUpdateState() internal {
        uint32 dUpper = 7 days;
        uint32 dLower = 1 days;
        uint32 rUpper = uint32(UNIT);
        uint32 rLower = uint32(UNIT);
        uint32 volMultiplier = uint32(UNIT);

        grappa.setProductMarginConfig(productId, dUpper, dLower, rUpper, rLower, volMultiplier);

        // test effect
        (
            uint32 _dUpper,
            uint32 _dLower,
            uint32 _sqrtDupper,
            uint32 _sqrtDLower,
            uint32 _rUpper,
            uint32 _rLower,
            uint32 _volMultiplier
        ) = grappa.productParams(productId);

        assertEq(_dUpper, dUpper);
        assertEq(_dLower, dLower);
        assertEq(_rUpper, rUpper);
        assertEq(_rLower, rLower);
        assertEq(_volMultiplier, volMultiplier);

        // squared value is set correctly
        assertEq(_sqrtDupper*_sqrtDupper, _dUpper);
        assertEq(_sqrtDLower*_sqrtDLower, _dLower);
    }

    function testCannotUpdateProductConfigFromNonOwner() internal {
        vm.startPrank(alice);
        vm.expectRevert("Owner: caller is not the owner");
        grappa.setProductMarginConfig(productId, 0, 0, uint32(UNIT), uint32(UNIT), uint32(UNIT));
        vm.stopPrank();
    }
}
