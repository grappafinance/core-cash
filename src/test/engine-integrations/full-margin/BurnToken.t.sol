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
contract TestBurnOption_FM is FullMarginFixture {
    uint256 public expiry;
    uint256 public strikePrice = 4000 * UNIT;
    uint256 public depositAmount = 1 ether;
    uint256 public amount = 1 * UNIT;
    uint256 public tokenId;

    function setUp() public {
        weth.mint(address(this), depositAmount);
        weth.approve(address(fmEngine), type(uint256).max);

        expiry = block.timestamp + 14 days;

        oracle.setSpotPrice(address(weth), 3000 * UNIT);

        // mint a 3000 strike call first
        tokenId = getTokenId(TokenType.CALL, pidEthCollat, expiry, strikePrice, 0);

        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = createAddCollateralAction(wethId, address(this), depositAmount);
        actions[1] = createMintAction(tokenId, address(this), amount);
        grappa.execute(fmEngineId, address(this), actions);
    }

    function testBurn() public {
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(tokenId, address(this), amount);

        // action
        grappa.execute(fmEngineId, address(this), actions);
        (uint256 shortId, uint64 shortAmount, , ) = fmEngine.marginAccounts(address(this));

        // check result
        assertEq(shortId, 0);
        assertEq(shortAmount, 0);
        assertEq(option.balanceOf(address(this), tokenId), 0);
    }

    function testCannotBurnWithWrongTokenId() public {
        address subAccount = address(uint160(address(this)) - 1);

        // badId: usdc Id
        uint256 badTokenId = getTokenId(TokenType.CALL, pidUsdcCollat, expiry, strikePrice, 0);
        // build burn account
        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = createBurnAction(badTokenId, address(this), amount);

        // action
        vm.expectRevert(FM_InvalidToken.selector);
        grappa.execute(fmEngineId, subAccount, actions); // execute on subaccount
    }
}
