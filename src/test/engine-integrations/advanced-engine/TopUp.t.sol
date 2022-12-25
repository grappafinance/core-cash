// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {AdvancedFixture} from "./AdvancedFixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

// contract TestTopupCallAccount is AdvancedFixture {
//     uint256 public expiry;

//     uint64 private amount = uint64(1 * UNIT);
//     uint256 private tokenId;
//     uint64 private strike;
//     uint256 private initialCollateral;

//     address private accountId;

//     function setUp() public {
//         // setup account for alice
//         usdc.mint(alice, 1000_000 * 1e6);

//         vm.startPrank(alice);
//         usdc.approve(address(engine), type(uint256).max);

//         expiry = block.timestamp + 7 days;

//         oracle.setSpotPrice(address(weth), 3500 * UNIT);

//         // mint option
//         initialCollateral = 500 * 1e6;

//         strike = uint64(4000 * UNIT);

//         accountId = alice;

//         tokenId = getTokenId(DerivativeType.CALL, SettlementType.CASH, productId, expiry, strike, 0);
//         ActionArgs[] memory actions = new ActionArgs[](2);
//         actions[0] = createAddCollateralAction(usdcId, alice, initialCollateral);
//         // give optoin to this address, so it can liquidate alice
//         actions[1] = createMintAction(tokenId, address(this), amount);

//         // mint option
//         engine.execute(accountId, actions);

//         vm.stopPrank();
//     }

//     function testAliceCanTopUpHerAccount() public {
//         vm.startPrank(alice);

//         uint256 usdcBalanceBefore = usdc.balanceOf(alice);
//         uint256 systemUsdcBalanceBefore = usdc.balanceOf(address(grappa));
//         (, , , , uint80 collateralBefore, ) = engine.marginAccounts(accountId);

//         engineId.topUp(accountId, uint80(initialCollateral));

//         uint256 usdcBalanceAfter = usdc.balanceOf(alice);
//         uint256 systemUsdcBalanceAfter = usdc.balanceOf(address(grappa));
//         (, , , , uint80 collateralAfter, ) = engine.marginAccounts(accountId);

//         assertEq(usdcBalanceBefore - usdcBalanceAfter, initialCollateral);
//         assertEq(systemUsdcBalanceAfter - systemUsdcBalanceBefore, initialCollateral);
//         assertEq(collateralAfter - collateralBefore, initialCollateral);

//         vm.stopPrank();
//     }

//     function testAnyoneCanTopUpAliceAccount() public {
//         usdc.mint(address(this), initialCollateral);
//         usdc.approve(address(engine), type(uint256).max);

//         uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
//         uint256 systemUsdcBalanceBefore = usdc.balanceOf(address(grappa));
//         (, , , , uint80 collateralBefore, ) = engine.marginAccounts(accountId);

//         engineId.topUp(accountId, uint80(initialCollateral));

//         uint256 usdcBalanceAfter = usdc.balanceOf(address(this));
//         uint256 systemUsdcBalanceAfter = usdc.balanceOf(address(grappa));
//         (, , , , uint80 collateralAfter, ) = engine.marginAccounts(accountId);

//         assertEq(usdcBalanceBefore - usdcBalanceAfter, initialCollateral);
//         assertEq(systemUsdcBalanceAfter - systemUsdcBalanceBefore, initialCollateral);
//         assertEq(collateralAfter - collateralBefore, initialCollateral);
//     }
// }
