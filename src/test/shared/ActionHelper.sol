// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/types/MarginAccountTypes.sol";
import "src/constants/MarginAccountEnums.sol";

contract ActionHelper {
    function createAddCollateralAction(address collateral, uint256 amount)
        internal
        pure
        returns (ActionArgs memory action)
    {
        action = ActionArgs({action: ActionType.AddCollateral, data: abi.encode(collateral, amount)});
    }

    function createRemoveCollateralAction(uint256 amount, address recipient)
        internal
        pure
        returns (ActionArgs memory action)
    {
        action = ActionArgs({action: ActionType.RemoveCollateral, data: abi.encode(amount, recipient)});
    }
}
