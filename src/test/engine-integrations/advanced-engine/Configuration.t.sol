// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base.
import {AdvancedFixture} from "../../shared/AdvancedFixture.t.sol";

import "../../../config/constants.sol";
import "../../../core/engines/advanced-margin/AdvancedMarginEngine.sol";

contract OwnerConfiguration is AdvancedFixture {
    event ProductConfigurationUpdated(
        uint32 productId,
        uint32 dUpper,
        uint32 dLower,
        uint32 rUpper,
        uint32 rLower,
        uint32 volMul
    );

    function testSettingConfigUpdateState() public {
        uint32 dUpper = 1000_000; // 11.57 days, 1000^2
        uint32 dLower = 90_000; // 1.04 days, 30^2
        uint32 rUpper = uint32(UNIT);
        uint32 rLower = uint32(UNIT);
        uint32 volMultiplier = uint32(UNIT);

        amEngine.setProductMarginConfig(productId, dUpper, dLower, rUpper, rLower, volMultiplier);

        // test effect
        (
            uint32 _dUpper,
            uint32 _dLower,
            uint32 _sqrtDupper,
            uint32 _sqrtDLower,
            uint32 _rUpper,
            uint32 _rLower,
            uint32 _volMultiplier
        ) = amEngine.productParams(productId);

        assertEq(_dUpper, dUpper);
        assertEq(_dLower, dLower);
        assertEq(_rUpper, rUpper);
        assertEq(_rLower, rLower);
        assertEq(_volMultiplier, volMultiplier);

        // squared value is set correctly
        assertEq(_sqrtDupper * _sqrtDupper, _dUpper);
        assertEq(_sqrtDLower * _sqrtDLower, _dLower);
    }

    function testEmitEventWhenSetConfig() public {
        uint32 dUpper = 7 days;
        uint32 dLower = 1 days;
        uint32 rUpper = uint32(UNIT / 2);
        uint32 rLower = uint32(UNIT / 10);
        uint32 volMultiplier = 1300000; // 130%

        vm.expectEmit(false, false, false, true, address(amEngine));
        emit ProductConfigurationUpdated(productId, dUpper, dLower, rUpper, rLower, volMultiplier);
        amEngine.setProductMarginConfig(productId, dUpper, dLower, rUpper, rLower, volMultiplier);
    }

    function testCannotUpdateProductConfigFromNonOwner() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        amEngine.setProductMarginConfig(productId, 0, 0, uint32(UNIT), uint32(UNIT), uint32(UNIT));
        vm.stopPrank();
    }
}
