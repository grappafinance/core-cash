// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {FullMarginFixtureV2} from "./FullMarginFixtureV2.t.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../utils/Console.sol";

/**
 * test full margin calculation for complicated structure
 */
contract TestpreviewMinCollateral_FMMV2 is FullMarginFixtureV2 {
    uint256 public expiry;
    uint256 public strikePrice;
    uint256 public amount;

    function setUp() public {
        expiry = block.timestamp + 14 days;

        strikePrice = 4000 * UNIT;
        amount = 1 * UNIT;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testSimulateCollateralReq_VanillaCall() public {
        Position[] memory shorts;
        Position[] memory longs;

        uint256 depositAmount = 1 * 1e18;

        uint256 tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        shorts = new Position[](1);
        shorts[0] = Position(tokenId, uint64(amount));

        longs = new Position[](0);

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, depositAmount);
    }

    function testSimulateCollateralReq_VanillaPut() public {
        Position[] memory shorts;
        Position[] memory longs;

        strikePrice = 2000 * UNIT;

        uint256 depositAmount = 2000 * 1e6;

        uint256 tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, strikePrice, 0);

        shorts = new Position[](1);
        shorts[0] = Position(tokenId, uint64(amount));

        longs = new Position[](0);

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, depositAmount);
    }

    function testSimulateCollateralReq_CallsPut1() public {
        Position[] memory shorts;
        Position[] memory longs;

        uint256 c4000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 4000 * UNIT, 0);
        uint256 p2000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 2000 * UNIT, 0);

        shorts = new Position[](2);
        shorts[0] = Position(c4000, uint64(amount));
        shorts[1] = Position(p2000, uint64(amount));

        longs = new Position[](0);

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, 1 * 1e18);
        assertEq(balances[1].collateralId, usdcId);
        assertEq(balances[1].amount, 2000 * 1e6);
    }

    function testSimulateCollateralReq_CallsPut2() public {
        Position[] memory shorts;
        Position[] memory longs;

        uint256 c4000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 4000 * UNIT, 0);
        uint256 c5000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 5000 * UNIT, 0);

        uint256 p2000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 2000 * UNIT, 0);
        uint256 p1000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);

        shorts = new Position[](2);
        shorts[0] = Position(c4000, uint64(amount));
        shorts[1] = Position(p2000, uint64(amount));

        longs = new Position[](2);
        longs[0] = Position(c5000, uint64(amount));
        longs[1] = Position(p1000, uint64(amount));

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, (((1000 * UNIT) / 5000) * (10**(18 - 6))));
        assertEq(balances[1].collateralId, usdcId);
        assertEq(balances[1].amount, 1000 * 1e6);
    }

    function testSimulateCollateralReq_CallsPut3() public {
        Position[] memory shorts;
        Position[] memory longs;

        oracle.setSpotPrice(address(weth), 19000 * UNIT);

        uint256 p17000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 17000 * UNIT, 0);
        uint256 p18000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 18000 * UNIT, 0);

        uint256 c21000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 21000 * UNIT, 0);
        uint256 c22000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 22000 * UNIT, 0);
        uint256 c25000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 25000 * UNIT, 0);
        uint256 c26000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 26000 * UNIT, 0);

        shorts = new Position[](4);
        shorts[0] = Position(p17000, uint64(1 * UNIT));
        shorts[1] = Position(c21000, uint64(1 * UNIT));
        shorts[2] = Position(c22000, uint64(8 * UNIT));
        shorts[3] = Position(c26000, uint64(8 * UNIT));

        longs = new Position[](2);
        longs[0] = Position(p18000, uint64(1 * UNIT));
        longs[1] = Position(c25000, uint64(16 * UNIT));

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        uint256 underlyingMaxLoss = (((((25000 - 21000) * 1) + ((25000 - 22000) * 8)) * UNIT) / 25000) * (10**(18 - 6));

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, underlyingMaxLoss);
    }

    function testSimulateCollateralReq_CallsPut4() public {
        Position[] memory shorts;
        Position[] memory longs;

        oracle.setSpotPrice(address(weth), 19000 * UNIT);

        uint256 p17000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 17000 * UNIT, 0);
        uint256 p18000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 18000 * UNIT, 0);

        uint256 c21000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 21000 * UNIT, 0);
        uint256 c22000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 22000 * UNIT, 0);
        uint256 c25000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 25000 * UNIT, 0);
        uint256 c26000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 26000 * UNIT, 0);
        uint256 c27000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 27000 * UNIT, 0);

        shorts = new Position[](5);
        shorts[0] = Position(p18000, uint64(1 * UNIT));
        shorts[1] = Position(c21000, uint64(1 * UNIT));
        shorts[2] = Position(c22000, uint64(8 * UNIT));
        shorts[3] = Position(c26000, uint64(8 * UNIT));
        shorts[4] = Position(c27000, uint64(1 * UNIT));

        longs = new Position[](2);
        longs[0] = Position(p17000, uint64(1 * UNIT));
        longs[1] = Position(c25000, uint64(16 * UNIT));

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1000 * 1e6);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 2 * 1e18);
    }

    function testSimulateCollateralReq_ShortStrangle() public {
        Position[] memory shorts;
        Position[] memory longs;

        oracle.setSpotPrice(address(weth), 1800 * UNIT);

        uint256 p1600 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1600 * UNIT, 0);
        uint256 c1900 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 1900 * UNIT, 0);

        shorts = new Position[](2);
        shorts[0] = Position(p1600, uint64(1 * UNIT));
        shorts[1] = Position(c1900, uint64(1 * UNIT));

        longs = new Position[](0);

        Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

        assertEq(balances.length, 2);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 1600 * 1e6);
        assertEq(balances[1].collateralId, wethId);
        assertEq(balances[1].amount, 1 * 1e18);
    }
}
