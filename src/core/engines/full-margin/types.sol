// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../config/enums.sol";

struct FullMarginAccount {
    uint256 tokenId;
    uint64 shortAmount;
    uint8 collateralId;
    uint80 collateralAmount;
}

struct FullMarginDetail {
    uint256 shortAmount;
    uint256 longStrike;
    uint256 shortStrike;
    uint256 collateralAmount;
    uint8 collateralDecimals;
    bool collateralizedWithStrike;
    TokenType optionType;
}
