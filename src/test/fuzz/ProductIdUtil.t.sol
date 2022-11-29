// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ProductIdUtil} from "../../libraries/ProductIdUtil.sol";

contract ProductIdUtilTest is Test {
    function testFormatAndParseAreMirrored(uint8 id0, uint8 id1, uint8 id2, uint8 id3, uint8 id4) public {
        uint40 id = ProductIdUtil.getProductId(id0, id1, id2, id3, id4);
        (uint8 _id0, uint8 _id1, uint8 _id2, uint8 _id3, uint8 _id4) = ProductIdUtil.parseProductId(id);

        assertEq(_id0, id0);
        assertEq(_id1, id1);
        assertEq(_id2, id2);
        assertEq(_id3, id3);
        assertEq(_id4, id4);
    }
}
