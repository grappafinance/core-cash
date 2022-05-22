// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

interface IMarginAccount {
    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    error NoAccess();

    error WrongCollateral();

    error InvalidShortTokenToMint();

    error AccountUnderwater();
}
