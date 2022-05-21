// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {OptionTokenUtils} from "../../libraries/OptionTokenUtils.sol";
import "../../libraries/TokenEnums.sol";

import {console} from "../utils/Console.sol";

contract OptionTokenUtilsTest is DSTest {
    function testTokenIdFuzz(
        TokenType tokenType,
        uint32 productId,
        uint64 expiry,
        uint64 longStrike,
        uint64 shortStrike
    ) public {
        // Vm.assume(uint8(tokenType) < 4);
        uint256 id = OptionTokenUtils.formatTokenId(
            tokenType,
            productId,
            expiry,
            longStrike,
            shortStrike
        );

        // (
        //     TokenType _tokenType,
        //     uint32 _productId,
        //     uint64 _expiry,
        //     uint64 _longStrike,
        //     uint64 _shortStrike
        // ) = OptionTokenUtils.parseTokenId(id);

        console.log("id", uint8(id));

        // assertEq(uint8(tokenType), uint8(_tokenType));
        // assertEq(uint32(productId), uint32(_productId));
        // assertEq(uint64(expiry), uint64(_expiry));
        // assertEq(uint64(longStrike), uint64(_longStrike));
        // assertEq(uint64(shortStrike), uint64(_shortStrike));
    }
}
