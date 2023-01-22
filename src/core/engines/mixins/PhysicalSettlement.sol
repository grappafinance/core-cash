// SPDX-License-Identifier: MIT
// solhint-disable no-empty-blocks
pragma solidity ^0.8.0;

import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// inheriting contracts
import {BaseEngine} from "../BaseEngine.sol";
import {IPhysicalSettlement} from "../../../interfaces/IPhysicalSettlement.sol";

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
    using FixedPointMathLib for uint256;
    using SafeCast for uint256;

    /// @dev window to exercise physical token
    uint256 private _settlementWindow;

    /// @dev token => TokenTracker
    mapping(uint256 => TokenTracker) public tokenTracker;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;

    /*///////////////////////////////////////////////////////////////
                        Override Internal Functions
    //////////////////////////////////////////////////////////////*/

    function getBatchSettlementForShorts(uint256 [] calldata _tokenIds, uint256[] calldata _amounts) external view returns (
        Balance[] memory debts, 
        Balance[] memory payouts
    ) {
        (debts, payouts) = grappa.getBatchSettlement(_tokenIds, _amounts);

        for (uint i; i < debts.length; ) {
            TokenTracker memory tracker = tokenTracker[_tokenIds[i]];

            // if the token is physical settled, tracker.issued will be positive
            // total amount exercised will be recorded and should be socialized to all short
            if (tracker.issued > 0) {
                debts[i].amount = uint256(debts[i].amount).mulDivDown(tracker.exercised, tracker.issued).toUint80();
                payouts[i].amount = uint256(payouts[i].amount).mulDivDown(tracker.exercised, tracker.issued).toUint80();
            } 

            unchecked { ++i; }
        }
    }

    /**
     * @dev mint option token to _subAccount, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOption(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        tokenTracker[tokenId].issued += amount;
    }

    /**
     * @dev mint option token into account, increase tracker issuance
     * @param _data bytes data to decode
     */
    function _mintOptionIntoAccount(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._mintOptionIntoAccount(_subAccount, _data);

        // decode tokenId
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        // grappa.trackTokenIssuance(tokenId, amount, true);
        tokenTracker[tokenId].issued += amount;
    }

    /**
     * @dev burn option token from user, decrease tracker issuance
     * @param _data bytes data to decode
     */
    function _burnOption(address _subAccount, bytes calldata _data) internal virtual override {
        BaseEngine._burnOption(_subAccount, _data);

        // decode parameters
        (uint256 tokenId,, uint64 amount) = abi.decode(_data, (uint256, address, uint64));

        tokenTracker[tokenId].issued -= amount;
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
