// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Setup} from "./Setup.t.sol";

/**
 * @dev test getPayout function on different token types
 */
contract GrappaSettlementTest is Setup {
    function setUp() public {
        _setupGrappaTestEnvironment();
    }

    function testSettleUSDCCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, usdcCollatProductId, 1e6);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 2300e6);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(usdc.balanceOf(address(this)), 300e6);
    }

    function testSettleETHCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, wethCollatProductId, 1e6);
        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 2500e6);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(weth.balanceOf(address(this)), 0.2e18);
    }

    function testSettleUSDCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, usdcCollatProductId, 1e6);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 1500e6);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(usdc.balanceOf(address(this)), 500e6);
    }

    function testSettleETHCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, wethCollatProductId, 1e6);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 1600e6);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(weth.balanceOf(address(this)), 0.25e18);
    }

    function testSettleUSDCCollatCallSpread() public {
        // arrange
        uint256 tokenId = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 2300e6);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(usdc.balanceOf(address(this)), 200e6);
    }

    function testSettleETHCollatPUTSpread() public {
        // arrange
        uint256 tokenId = _mintPutSpread(2000e6, 1800e6, wethCollatProductId, 1e6);
        uint256 expiryPrice = 1600e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        grappa.settleOption(address(this), tokenId, 1e6);

        // assertion
        assertEq(weth.balanceOf(address(this)), 0.125e18);
    }

    function testSettleSameCollat() public {
      uint256[] memory ids = new uint256[](3);
      uint256[] memory amounts = new uint256[](3);
      ids[0] = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);
      ids[1] = _mintCallOption(2000e6, usdcCollatProductId, 1e6);
      ids[2] = _mintPutOption(2500e6, usdcCollatProductId, 1e6);

      amounts[0] = 1e6;
      amounts[1] = 1e6;
      amounts[2] = 1e6;

      vm.warp(expiry);
      oracle.setExpiryPrice(address(weth), address(usdc), 2600e6);

      // act
      grappa.batchSettleOptions(address(this), ids, amounts);

      // assertion
      uint expectedPayout = (200 + 600) * 1e6;
      assertEq(usdc.balanceOf(address(this)), expectedPayout);
    }

    function testSettleDiffCollat() public {
      uint256[] memory ids = new uint256[](3);
      uint256[] memory amounts = new uint256[](3);
      ids[0] = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);
      ids[1] = _mintCallOption(2000e6, wethCollatProductId, 1e6); // eth collat call
      ids[2] = _mintCallOption(2000e6, usdcCollatProductId, 1e6); // usdc collatf

      amounts[0] = 1e6;
      amounts[1] = 1e6;
      amounts[2] = 1e6;

      vm.warp(expiry);
      oracle.setExpiryPrice(address(weth), address(usdc), 2500e6);

      // act
      grappa.batchSettleOptions(address(this), ids, amounts);

      // assertion
      uint expectedUSDC = (200 + 500) * 1e6;
      assertEq(usdc.balanceOf(address(this)), expectedUSDC);

      uint expectedWETH = 0.2e18;
      assertEq(weth.balanceOf(address(this)), expectedWETH);
    }
}
