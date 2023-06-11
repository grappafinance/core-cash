// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Setup} from "./Setup.t.sol";

/**
 * @dev test getPayout function on different token types
 */
contract GrappaPayoutTest is Setup {
    function setUp() public {
        _setupGrappaTestEnvironment();
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
}
