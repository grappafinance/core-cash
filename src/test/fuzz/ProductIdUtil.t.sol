// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "forge-std/Test.sol";
import {ProductIdUtil} from "../../libraries/ProductIdUtil.sol";

contract ProductIdUtilTest is Test {
    function testFormatAndParseAreMirrored(
        uint8 id1,
        uint8 id2,
        uint8 id3
    ) public {
        uint32 id = ProductIdUtil.getProductId(id1, id2, id3);
        (uint8 _id1, uint8 _id2, uint8 _id3) = ProductIdUtil.parseProductId(id);

        assertEq(_id1, id1);
        assertEq(_id2, id2);
        assertEq(_id3, id3);
    }
}
