// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

interface IMarginAccount {
    /*///////////////////////////////////////////////////////////////
                                  Types
    //////////////////////////////////////////////////////////////*/

    /// @dev each margin position
    struct Account {
        uint256 shortCallId; // link to call or call spread
        uint256 shortPutId; // link to put or put spread
        uint80 shortCallAmount;
        uint80 shortLongAmount;
        uint80 collateralAmount;
        bool isStrikeCollateral;
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIED();
}
