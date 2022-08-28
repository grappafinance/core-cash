// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import test base and helpers.
import {FullMarginFixture} from "../../shared/FullMarginFixture.t.sol";
import {stdError} from "forge-std/Test.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestLiquidate_FM is FullMarginFixture {
    uint64 private amount = uint64(1 * UNIT);
    uint256 private collatAmount = 1 ether;

    function setUp() public {
        weth.mint(address(this), collatAmount);
        weth.approve(address(fmEngine), type(uint256).max);

        uint256 expiry = block.timestamp + 7 days;

        // mint option
        uint256 strike = uint64(4000 * UNIT);
        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strike, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), collatAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);

        // mint option
        grappa.execute(fmEngineId, address(this), actions);

        vm.stopPrank();
    }

    function testCannotLiquidate() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = 0;
        vm.expectRevert(FM_NoLiquidation.selector);
        grappa.liquidate(address(fmEngine), address(this), ids, amounts);

        assertEq(fmEngine.getMinCollateral(address(this)), collatAmount);
        assertEq(fmEngine.isAccountHealthy(address(this)), true);
    }
}
