// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../mocks/MockERC20.sol";
import "../../mocks/MockOracle.sol";
import {MockTransferableEngine} from "../../mocks/MockTransferableEngine.sol";

import "../../../src/core/Grappa.sol";
import "../../../src/core/GrappaProxy.sol";
import "../../../src/core/CashOptionToken.sol";

import "../../../src/config/enums.sol";
import "../../../src/config/types.sol";
import "../../types.sol";

import "../../utils/Utilities.sol";

// solhint-disable max-states-count
contract OptionTransferableTest is Utilities, Test {
    MockTransferableEngine internal engine;
    Grappa internal grappa;
    CashOptionToken internal option;

    MockERC20 internal usdc;
    MockERC20 internal weth;

    MockOracle internal oracle;

    // usdc collateralized call / put
    uint40 internal productId;

    uint8 internal usdcId;
    uint8 internal wethId;

    uint8 internal engineId;
    uint8 internal oracleId;

    // shared
    uint256 public tokenId;

    constructor() {
        usdc = new MockERC20("USDC", "USDC", 6); // nonce: 1
        weth = new MockERC20("WETH", "WETH", 18); // nonce: 2

        oracle = new MockOracle(); // nonce: 3

        // predict address of margin account and use it here
        address grappaAddr = predictAddress(address(this), 6);

        option = new CashOptionToken(grappaAddr, address(0)); // nonce: 4

        address grappaImplementation = address(new Grappa(address(option))); // nonce: 5

        bytes memory data = abi.encodeWithSelector(Grappa.initialize.selector, address(this));

        grappa = Grappa(address(new GrappaProxy(grappaImplementation, data))); // 6

        engine = new MockTransferableEngine(address(grappa), address(option)); // nonce 7

        // register products
        usdcId = grappa.registerAsset(address(usdc));
        wethId = grappa.registerAsset(address(weth));

        engineId = grappa.registerEngine(address(engine));
        oracleId = grappa.registerOracle(address(oracle));

        productId = grappa.getProductId(address(oracle), address(engine), address(weth), address(usdc), address(usdc));
    }

    function setUp() public {
        usdc.mint(address(this), 10000 * 1e6);
        usdc.approve(address(engine), type(uint256).max);

        weth.mint(address(this), 100 * 1e18);
        weth.approve(address(engine), type(uint256).max);

        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 4000 * UNIT;
        tokenId = getTokenId(TokenType.CALL, productId, expiry, strikePrice, 0);
    }

    function _setupDefaultAccount() public {
        ActionArgs[] memory actions = new ActionArgs[](2);
        actions[0] = ActionArgs({action: ActionType.AddCollateral, data: abi.encode(address(this), uint80(1000 * UNIT), usdcId)});
        actions[1] = ActionArgs({action: ActionType.MintShort, data: abi.encode(tokenId, address(this), uint64(1 * UNIT))});

        engine.execute(address(this), actions);
    }

    function testCanTransferCollat() public {
        _setupDefaultAccount();

        address subAccount = address(uint160(address(this)) - 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.TransferCollateral, data: abi.encode(uint80(400 * UNIT), subAccount, usdcId)});

        // this will invoke _removeCollateralFromAccount, _addCollateralToAccount
        engine.execute(subAccount, actions);
    }

    function testTransferLong() public {
        _setupDefaultAccount();

        uint256 balanceBefore = option.balanceOf(address(engine), tokenId);

        address subAccount = address(uint160(address(this)) - 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.TransferLong, data: abi.encode(tokenId, subAccount, uint64(1 * UNIT))});

        engine.execute(subAccount, actions);

        assertEq(option.balanceOf(address(engine), tokenId), balanceBefore);
    }

    function testTransferShort() public {
        _setupDefaultAccount();

        uint256 balanceBefore = option.balanceOf(address(engine), tokenId);

        address subAccount = address(uint160(address(this)) - 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.TransferShort, data: abi.encode(tokenId, subAccount, uint64(1 * UNIT))});

        engine.setIsAboveWater(subAccount, true);
        engine.execute(subAccount, actions);

        assertEq(option.balanceOf(address(engine), tokenId), balanceBefore);
    }

    function testCannotTransferShortIfEndingUnderwater() public {
        _setupDefaultAccount();

        address subAccount = address(uint160(address(this)) - 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] = ActionArgs({action: ActionType.TransferShort, data: abi.encode(tokenId, subAccount, uint64(1 * UNIT))});

        vm.expectRevert(BM_AccountUnderwater.selector);
        engine.execute(subAccount, actions);
    }

    function testMintOptionToOtherAccount() public {
        _setupDefaultAccount();

        address subAccount = address(uint160(address(this)) - 1);

        ActionArgs[] memory actions = new ActionArgs[](1);
        actions[0] =
            ActionArgs({action: ActionType.MintShortIntoAccount, data: abi.encode(tokenId, subAccount, uint64(1 * UNIT))});

        engine.setIsAboveWater(address(this), true);
        engine.execute(subAccount, actions);

        // option is minted to the engine
        assertEq(option.balanceOf(address(engine), tokenId), 1 * UNIT);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
