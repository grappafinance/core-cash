// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import test base and helpers.
import "forge-std/Test.sol";

import {Grappa} from "../../core/Grappa.sol";
import {GrappaProxy} from "../../core/GrappaProxy.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

import "../../config/errors.sol";
import "../../config/enums.sol";
import "../../config/constants.sol";

/**
 * @dev test grappa register related functions
 */
contract GrappaRegistry is Test {
    Grappa public grappa;
    MockERC20 private weth;

    constructor() {
        weth = new MockERC20("WETH", "WETH", 18);

        // set option to 0
        address grappaImplementation = address(new Grappa(address(0))); // nonce: 5

        bytes memory data = abi.encode(Grappa.initialize.selector);

        grappa = Grappa(address(new GrappaProxy(grappaImplementation, data))); // 6
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        grappa.registerAsset(address(weth));
    }

    function testRegisterAssetFromId1() public {
        uint8 id = grappa.registerAsset(address(weth));
        assertEq(id, 1);

        assertEq(grappa.assetIds(address(weth)), id);
    }

    function testRegisterAssetRecordDecimals() public {
        uint8 id = grappa.registerAsset(address(weth));

        (address addr, uint8 decimals) = grappa.assets(id);

        assertEq(addr, address(weth));
        assertEq(decimals, 18);
    }

    function testCannotRegistrySameAssetTwice() public {
        grappa.registerAsset(address(weth));
        vm.expectRevert(GP_AssetAlreadyRegistered.selector);
        grappa.registerAsset(address(weth));
    }

    function testReturnAssetsFromProductId() public {
        grappa.registerAsset(address(weth));

        uint40 product = grappa.getProductId(address(0), address(0), address(weth), address(0), address(weth));

        (,, address underlying,, address strike,, address collateral, uint8 collatDecimals) =
            grappa.getDetailFromProductId(product);

        assertEq(underlying, address(weth));

        // strike is empty
        assertEq(strike, address(0));
        assertEq(underlying, address(weth));
        assertEq(collateral, address(weth));
        assertEq(collatDecimals, 18);
    }

    function testReturnOptionDetailsFromTokenId() public {
        uint256 expiryTimestamp = block.timestamp + 14 days;
        uint256 strikePrice = 4000 * UNIT;

        grappa.registerAsset(address(weth));

        uint40 product = grappa.getProductId(address(0), address(0), address(weth), address(0), address(weth));
        uint256 token = grappa.getTokenId(TokenType.CALL, SettlementType.CASH, product, expiryTimestamp, strikePrice, 0);

        (TokenType tokenType, SettlementType settlementType, uint40 productId, uint256 expiry, uint256 strike, uint256 reserved)
        = grappa.getDetailFromTokenId(token);

        assertEq(uint8(tokenType), uint8(TokenType.CALL));
        assertEq(uint8(settlementType), uint8(SettlementType.CASH));
        assertEq(productId, product);

        // strike is empty
        assertEq(expiry, expiryTimestamp);
        assertEq(strike, strikePrice);
        assertEq(reserved, 0);
    }
}

/**
 * @dev test grappa functions around registering engines
 */
contract RegisterEngineTest is Test {
    Grappa public grappa;
    address private engine1;

    constructor() {
        engine1 = address(1);
        address grappaImplementation = address(new Grappa(address(0))); // nonce: 5

        bytes memory data = abi.encode(Grappa.initialize.selector);

        grappa = Grappa(address(new GrappaProxy(grappaImplementation, data))); // 6
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        grappa.registerEngine(engine1);
    }

    function testRegisterEngineFromId1() public {
        uint8 id = grappa.registerEngine(engine1);
        assertEq(id, 1);

        assertEq(grappa.engineIds(engine1), id);
    }

    function testCannotRegistrySameEngineTwice() public {
        grappa.registerEngine(engine1);
        vm.expectRevert(GP_EngineAlreadyRegistered.selector);
        grappa.registerEngine(engine1);
    }

    function testReturnEngineFromProductId() public {
        grappa.registerEngine(engine1);

        uint40 product = grappa.getProductId(address(0), address(engine1), address(0), address(0), address(0));

        (, address engine,,,,,,) = grappa.getDetailFromProductId(product);

        assertEq(engine, engine1);
    }
}

/**
 * @dev test grappa functions around registering engines
 */
contract RegisterOracleTest is Test {
    Grappa public grappa;
    address private oracle;

    constructor() {
        oracle = address(new MockOracle());
        address grappaImplementation = address(new Grappa(address(0))); // nonce: 5
        bytes memory data = abi.encode(Grappa.initialize.selector);
        grappa = Grappa(address(new GrappaProxy(grappaImplementation, data))); // 6
    }

    function testCannotRegisterFromNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xaacc));
        grappa.registerOracle(oracle);
    }

    function testRegisterOracleFromId1() public {
        uint8 id = grappa.registerOracle(oracle);
        assertEq(id, 1);

        assertEq(grappa.oracleIds(oracle), id);
    }

    function testCannotRegistrySameOracleTwice() public {
        grappa.registerOracle(oracle);
        vm.expectRevert(GP_OracleAlreadyRegistered.selector);
        grappa.registerOracle(oracle);
    }

    function testCannotRegistryOralceWithDisputePeriodTooLong() public {
        MockOracle(oracle).setViewDisputePeriod(1 days);
        vm.expectRevert(GP_BadOracle.selector);
        grappa.registerOracle(oracle);
    }

    function testReturnEngineFromProductId() public {
        grappa.registerOracle(oracle);

        uint40 product = grappa.getProductId(address(oracle), address(0), address(0), address(0), address(0));

        (address oracle_,,,,,,,) = grappa.getDetailFromProductId(product);

        assertEq(oracle_, oracle);
    }
}
