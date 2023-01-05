// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";

// // constants and types
import "../../../config/constants.sol";
import "../../../config/enums.sol";
import "../../../config/errors.sol";
import "../../../config/types.sol";

/**
 * @title   PhysicalSettlement
 * @author  @dsshap
 * @notice  util functions for MarginEngines to support physically settled tokens
 */
abstract contract PhysicalSettlement is BaseEngine {
    /// @dev window to exercise physical token
    uint256 private _settlementWindow;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    /*///////////////////////////////////////////////////////////////
                        Override Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev mint option token to _subAccount, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOption(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        grappa.trackTokenIssuance(tokenId, amount, true);
    }

    /**
     * @dev mint option token into account, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOptionIntoAccount(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        grappa.trackTokenIssuance(tokenId, amount, true);
    }

    /**
     * @dev burn option token from user, decrease tracker issuance
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._burnOption(_subAccount, _data);

        // decode parameters
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        grappa.trackTokenIssuance(tokenId, amount, false);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev set new settlement window
     * @param _window is the time from expiry that the option can be exercised
     */
    function _setSettlementWindow(uint256 _window) internal virtual {
        if (_window < MIN_SETTLEMENT_WINDOW) revert PS_InvalidSettlementWindow();

        _settlementWindow = _window;
    }

    /**
     * @dev gets current settlement window
     */
    function _getSettlementWindow() internal view returns (uint256) {
        return _settlementWindow != 0 ? _settlementWindow : MIN_SETTLEMENT_WINDOW;
    }
}
