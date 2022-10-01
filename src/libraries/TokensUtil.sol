pragma solidity ^0.8.0;

import "../config/enums.sol";
import "./TokenIdUtil.sol";

import "../test/utils/Console.sol";

library TokensUtil {
    using TokenIdUtil for uint256;

    /**
     * @dev Returns options of a certain type
     * @return tokens
     * @return amounts
     */
    function getByTypeWithAmounts(
        uint256[] memory data,
        TokenType tokenType,
        uint64[] memory quantities
    ) internal pure returns (uint256[] memory tokens, uint64[] memory amounts) {
        uint256 count = 0;
        for (uint256 i; i < data.length; i++) {
            if (data[i].parseTokenType() == tokenType) count++;
        }
        tokens = new uint256[](count);
        amounts = new uint64[](count);
        uint256 y = 0;
        for (uint256 i; i < data.length; i++) {
            if (data[i].parseTokenType() == tokenType) {
                tokens[y] = data[i];
                amounts[y] = quantities[i];
                y++;
            }
        }
    }

    function getStrikes(uint256[] memory data) internal pure returns (uint64[] memory strikes) {
        strikes = new uint64[](data.length);
        for (uint256 i; i < data.length; i++) {
            (, , , uint64 longStrike, ) = data[i].parseTokenId();
            strikes[i] = longStrike;
        }
    }
}
