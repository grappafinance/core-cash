// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "src/interfaces/IPricer.sol";
import "src/interfaces/IOracle.sol";

contract MockPricer is IPricer {
    IOracle public oracle;

    uint192 public spotPrice;
    bool public shouldRevert;

    function setOracle(address _oracle) external {
        oracle = IOracle(_oracle);
    }

    function getSpotPrice(
        address, /*_underlying*/
        address /*_strike*/
    ) external view returns (uint256) {
        if (shouldRevert) revert("mock revert getSpot");
        return spotPrice;
    }

    function setPrice(uint256 _price) external {
        spotPrice = uint192(_price);
    }

    function setSpotRevert(bool _revert) external {
        shouldRevert = _revert;
    }

    function mockSetExpiryPrice(
        address _base,
        address _quote,
        uint256 _expiry,
        uint256 _price
    ) external {
        oracle.reportExpiryPrice(_base, _quote, _expiry, _price);
    }
}
