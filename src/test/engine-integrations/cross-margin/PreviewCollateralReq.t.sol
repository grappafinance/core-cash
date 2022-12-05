// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import {CrossMarginFixture} from "./CrossMarginFixture.t.sol";

import "../../../core/engines/cross-margin/AccountUtil.sol";

import "../../../config/enums.sol";
import "../../../config/types.sol";
import "../../../config/constants.sol";
import "../../../config/errors.sol";

import "../../../core/engines/cross-margin/types.sol";
import "../../../core/engines/cross-margin//AccountUtil.sol";

import "../../utils/Console.sol";

/**
 * test full margin calculation for complicated structure
 */
// solhint-disable-next-line contract-name-camelcase
contract TestpreviewMinCollateral_CMM is CrossMarginFixture {
    uint256 public expiry;
    uint256 public strikePrice;
    int256 public amount;

    struct OptionPosition {
        TokenType tokenType;
        uint256 strike;
        int256 amount;
    }

    function setUp() public {
        expiry = block.timestamp + 14 days;

        strikePrice = 4000 * UNIT;
        amount = 1 * sUNIT;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);
    }

    function testPreviewMinCollateralVanillaCall() public {
        uint256 depositAmount = 1 * 1e18;

        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.CALL, strikePrice, -amount);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, depositAmount);
    }

    function testPreviewMinCollateralVanillaPut() public {
        strikePrice = 2000 * UNIT;

        uint256 depositAmount = 2000 * 1e6;

        OptionPosition[] memory positions = new OptionPosition[](1);
        positions[0] = OptionPosition(TokenType.PUT, strikePrice, -amount);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, depositAmount);
    }

    // function testPreviewMinCollateralCallsPut1() public {
    //     Position[] memory shorts;
    //     Position[] memory longs;

    //     shorts = new Position[](2);
    //     shorts[0] = positionC(4000 * UNIT, amount);
    //     shorts[1] = positionP(2000 * UNIT, amount);

    //     longs = new Position[](0);

    //     Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

    //     assertEq(balances.length, 2);
    //     assertEq(balances[0].collateralId, usdcId);
    //     assertEq(balances[0].amount, 2000 * 1e6);
    //     assertEq(balances[1].collateralId, wethId);
    //     assertEq(balances[1].amount, 1 * 1e18);
    // }

    // function testPreviewMinCollateralCallsPut2() public {
    //     Position[] memory shorts;
    //     Position[] memory longs;

    //     uint256 c4000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 4000 * UNIT, 0);
    //     uint256 c5000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 5000 * UNIT, 0);

    //     uint256 p2000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 2000 * UNIT, 0);
    //     uint256 p1000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1000 * UNIT, 0);

    //     shorts = new Position[](2);
    //     shorts[0] = Position(c4000, uint64(amount));
    //     shorts[1] = Position(p2000, uint64(amount));

    //     longs = new Position[](2);
    //     longs[0] = Position(c5000, uint64(amount));
    //     longs[1] = Position(p1000, uint64(amount));

    //     Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

    //     assertEq(balances.length, 1);
    //     assertEq(balances[0].collateralId, usdcId);
    //     assertEq(balances[0].amount, 1000 * 1e6);
    // }

    function testPreviewMinCollateralCallsPut3() public {
        oracle.setSpotPrice(address(weth), 19000 * UNIT);

        OptionPosition[] memory positions = new OptionPosition[](6);
        positions[0] = OptionPosition(TokenType.PUT, 17000 * UNIT, -1 * sUNIT);
        positions[1] = OptionPosition(TokenType.PUT, 18000 * UNIT, 1 * sUNIT);
        positions[2] = OptionPosition(TokenType.CALL, 21000 * UNIT, -1 * sUNIT);
        positions[3] = OptionPosition(TokenType.CALL, 22000 * UNIT, -8 * sUNIT);
        positions[4] = OptionPosition(TokenType.CALL, 25000 * UNIT, 16 * sUNIT);
        positions[5] = OptionPosition(TokenType.CALL, 26000 * UNIT, -6 * sUNIT);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, usdcId);
        assertEq(balances[0].amount, 28000 * 1e6);
    }

    // function testPreviewMinCollateralCallsPut4() public {
    //     Position[] memory shorts;
    //     Position[] memory longs;

    //     oracle.setSpotPrice(address(weth), 19000 * UNIT);

    //     uint256 p17000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 17000 * UNIT, 0);
    //     uint256 p18000 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 18000 * UNIT, 0);

    //     uint256 c21000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 21000 * UNIT, 0);
    //     uint256 c22000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 22000 * UNIT, 0);
    //     uint256 c25000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 25000 * UNIT, 0);
    //     uint256 c26000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 26000 * UNIT, 0);
    //     uint256 c27000 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 27000 * UNIT, 0);

    //     shorts = new Position[](5);
    //     shorts[0] = Position(p18000, uint64(1 * UNIT));
    //     shorts[1] = Position(c21000, uint64(1 * UNIT));
    //     shorts[2] = Position(c22000, uint64(8 * UNIT));
    //     shorts[3] = Position(c26000, uint64(8 * UNIT));
    //     shorts[4] = Position(c27000, uint64(1 * UNIT));

    //     longs = new Position[](2);
    //     longs[0] = Position(p17000, uint64(1 * UNIT));
    //     longs[1] = Position(c25000, uint64(16 * UNIT));

    //     Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

    //     assertEq(balances.length, 1);
    //     assertEq(balances[0].collateralId, wethId);
    //     assertEq(balances[0].amount, 2 * 1e18);
    // }

    // function testPreviewMinCollateralShortStrangle() public {
    //     Position[] memory shorts;
    //     Position[] memory longs;

    //     oracle.setSpotPrice(address(weth), 1800 * UNIT);

    //     uint256 p1600 = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, 1600 * UNIT, 0);
    //     uint256 c1900 = getTokenId(TokenType.CALL, pidEthCollat, expiry, 1900 * UNIT, 0);

    //     shorts = new Position[](2);
    //     shorts[0] = Position(p1600, uint64(1 * UNIT));
    //     shorts[1] = Position(c1900, uint64(1 * UNIT));

    //     longs = new Position[](0);

    //     Balance[] memory balances = engine.previewMinCollateral(shorts, longs);

    //     assertEq(balances.length, 2);
    //     assertEq(balances[0].collateralId, usdcId);
    //     assertEq(balances[0].amount, 1600 * 1e6);
    //     assertEq(balances[1].collateralId, wethId);
    //     assertEq(balances[1].amount, 1 * 1e18);
    // }

    function testPreviewMinCollateralCallSpread() public {
        uint256 depositAmount = 1 * 1e18;

        OptionPosition[] memory positions = new OptionPosition[](2);
        positions[0] = OptionPosition(TokenType.CALL, strikePrice / 2, -amount);
        positions[1] = OptionPosition(TokenType.CALL, strikePrice, amount);

        Balance[] memory balances = _previewMinCollateral(positions);

        assertEq(balances.length, 1);
        assertEq(balances[0].collateralId, wethId);
        assertEq(balances[0].amount, depositAmount / 2);
    }

    function _previewMinCollateral(OptionPosition[] memory postions) internal returns (Balance[] memory balances) {
        (Position[] memory shorts, Position[] memory longs) = _convertPositions(postions);
        balances = engine.previewMinCollateral(shorts, longs);
    }

    function _convertPositions(OptionPosition[] memory positions)
        internal
        view
        returns (Position[] memory shorts, Position[] memory longs)
    {
        for (uint256 i = 0; i < positions.length; i++) {
            OptionPosition memory position = positions[i];

            uint256 tokenId = TokenType.CALL == position.tokenType ? _callTokenId(position.strike) : _putTokenId(position.strike);

            if (position.amount < 0) {
                shorts = AccountUtil.append(shorts, Position(tokenId, uint64(uint256(-position.amount))));
            } else {
                longs = AccountUtil.append(longs, Position(tokenId, uint64(uint256(position.amount))));
            }
        }
    }

    function _callTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, _strikePrice, 0);
    }

    function _putTokenId(uint256 _strikePrice) internal view returns (uint256 tokenId) {
        tokenId = getTokenId(TokenType.PUT, pidUsdcCollat, expiry, _strikePrice, 0);
    }
}
