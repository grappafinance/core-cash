// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Setup} from "./Setup.t.sol";
import "../../src/config/types.sol";
import "../../src/config/errors.sol";

/**
 * @dev test getPayout function on different token types
 */
contract GrappaPayoutTest is Setup {
    function setUp() public {
        _setupGrappaTestEnvironment();
    }

    function testCannotGetPayoutBeforeExpiry() public {
        uint256 tokenId = _mintCallOption(2000e6, usdcCollatProductId, 1e6);

        vm.expectRevert(GP_NotExpired.selector);
        grappa.getPayout(tokenId, 1e6);
    }

    function testPayoutUSDCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 2300e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 300e6);
    }

    function testPayoutETHCollatCall() public {
        // arrange
        uint256 tokenId = _mintCallOption(2000e6, wethCollatProductId, 1e6);
        vm.warp(expiry);
        uint256 expiryPrice = 2300e6;
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertApproxEqAbs(payout, 300e6 * 1e18 / expiryPrice, 0.0001e18);
    }

    function testPayoutUSDCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 1500e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 500e6);
    }

    function testPayoutETHCollatPut() public {
        // arrange
        uint256 tokenId = _mintPutOption(2000e6, wethCollatProductId, 1e6);
        uint256 expiryPrice = 1600e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertEq(payout, 0.25e18); // 400 payout with 1600 each eth
    }

    function testPayoutUSDCCollatCallSpread() public {
        // arrange
        uint256 tokenId = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);
        uint256 expiryPrice = 2300e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(usdc));
        assertEq(payout, 200e6);
    }

    function testPayoutETHCollatPUTSpread() public {
        // arrange
        uint256 tokenId = _mintPutSpread(2000e6, 1800e6, wethCollatProductId, 1e6);
        uint256 expiryPrice = 1600e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), expiryPrice);

        // act
        (address engine_, address _collat, uint256 payout) = grappa.getPayout(tokenId, 1e6);

        // assertion
        assertEq(engine_, address(engine));
        assertEq(_collat, address(weth));
        assertEq(payout, 0.125e18); // payout 200 with 1600 each eth
    }

    function testCanGetBatchPayout() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = _mintCallSpread(2000e6, 2200e6, usdcCollatProductId, 1e6);
        ids[1] = _mintCallOption(2000e6, wethCollatProductId, 1e6); // eth collat call
        ids[2] = _mintCallOption(2000e6, usdcCollatProductId, 1e6); // usdc collat

        amounts[0] = 1e6;
        amounts[1] = 1e6;
        amounts[2] = 1e6;

        vm.warp(expiry);
        oracle.setExpiryPrice(address(weth), address(usdc), 2500e6);

        Balance[] memory result = grappa.batchGetPayouts(ids, amounts);

        // assertion
        assertEq(result[0].collateralId, usdcId);
        assertEq(result[1].collateralId, wethId);

        uint256 expectedUSDC = (200 + 500) * 1e6;
        assertEq(result[0].amount, expectedUSDC);

        uint256 expectedWETH = 0.2e18;
        assertEq(result[1].amount, expectedWETH);
    }
}
