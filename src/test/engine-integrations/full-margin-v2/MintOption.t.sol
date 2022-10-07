// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginV2Fixture} from "./FullMarginV2Fixture.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../test/mocks/MockERC20.sol";

// solhint-disable-next-line contract-name-camelcase
contract TestMint_FM2 is FullMarginV2Fixture {
    uint256 public expiry;

    function setUp() public {
        usdc.mint(address(this), 1000_000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testMintCall() public {
        uint256 depositAmount = 1000 * 1e6;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        uint256 shortAmount = engine.getAccountShortAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePrice),
            true
        );
        assertEq(shortAmount, amount);
    }

    function testMintCallSpread() public {
        uint256 depositAmount = 100 * 1e6;

        uint256 strikePriceLower = 4000 * UNIT;
        uint256 strikePriceHigher = 4100 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.CALL_SPREAD, pidUsdcCollat, expiry, strikePriceLower, strikePriceHigher);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        uint256 shortAmount = engine.getAccountShortAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePriceLower),
            true
        );
        uint256 longAmount = engine.getAccountLongAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePriceHigher),
            true
        );
        assertEq(shortAmount, amount);
        assertEq(longAmount, amount);
    }

    function testMintPut() public {
        uint256 depositAmount = 1000 * 1e6;

        uint256 strikePrice = 4000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        uint256 shortAmount = engine.getAccountShortAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePrice),
            false
        );
        assertEq(shortAmount, amount);
    }

    function testMintPutSpread() public {
        uint256 depositAmount = 100 * 1e6;

        uint256 strikePriceLower = 2900 * UNIT;
        uint256 strikePriceHigher = 3000 * UNIT;
        uint256 amount = 1 * UNIT;

        uint256 tokenId = getTokenId(TokenType.PUT_SPREAD, pidUsdcCollat, expiry, strikePriceHigher, strikePriceLower);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(usdcId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        engine.execute(address(this), actions);
        uint256 shortAmount = engine.getAccountShortAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePriceHigher),
            false
        );
        uint256 longAmount = engine.getAccountLongAmount(
            address(this),
            pidUsdcCollat,
            uint64(expiry),
            uint64(strikePriceLower),
            false
        );
        assertEq(shortAmount, amount);
        assertEq(longAmount, amount);
    }
}
