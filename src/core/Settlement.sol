// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

// external librares
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// inheriting cotract
import {Registry} from "./Registry.sol";

// libraries
import {TokenIdUtil} from "../libraries/TokenIdUtil.sol";
import {ProductIdUtil} from "../libraries/ProductIdUtil.sol";

// interfaces
import {IOptionToken} from "../interfaces/IOptionToken.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IMarginEngine} from "../interfaces/IMarginEngine.sol";

// constants and types
import "../config/enums.sol";
import "../config/constants.sol";
import "../config/errors.sol";
import "../config/types.sol";

/**
 * @title   Settlement
 * @dev     this module takes care of settling option tokens. 
            By inheriting Registry, this module can have easy access to all product / asset details 
 */
contract Settlement is Registry {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    /// @dev optionToken address
    IOptionToken public immutable optionToken;

    constructor(address _optionToken) {
        optionToken = IOptionToken(_optionToken);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenId  tokenId of option token to burn
     * @param _amount   amount to settle
     */
    function settleOption(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    ) external {
        (address collateral, uint256 payout) = getOptionPayout(_tokenId, uint64(_amount));

        optionToken.burn(_account, _tokenId, _amount);

        IERC20(collateral).safeTransfer(_account, payout);
    }

    /**
     * @notice burn option token and get out cash value at expiry
     *
     * @param _account who to settle for
     * @param _tokenIds array of tokenIds to burn
     * @param _amounts   array of amounts to burn
     * @param _collateral collateral asset to settle in.
     */
    function batchSettleOptions(
        address _account,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _collateral
    ) external {
        if (_tokenIds.length != _amounts.length) revert ST_WrongArgumentLength();

        uint256 totalPayout;

        for (uint256 i; i < _tokenIds.length; ) {
            (address collateral, uint256 payout) = getOptionPayout(_tokenIds[i], uint64(_amounts[i]));

            if (collateral != _collateral) revert ST_WrongSettlementCollateral();
            totalPayout += payout;

            unchecked {
                i++;
            }
        }

        optionToken.batchBurn(_account, _tokenIds, _amounts);

        IERC20(_collateral).safeTransfer(_account, totalPayout);
    }

    function getOptionPayout(uint256 _tokenId, uint64 _amount)
        public
        view
        returns (address collateral, uint256 payout)
    {
        (, uint32 productId, , , ) = TokenIdUtil.parseTokenId(_tokenId);
        (uint8 engineId, , , ) = ProductIdUtil.parseProductId(productId);
        (collateral, payout) = IMarginEngine(engines[engineId]).getPayout(_tokenId, _amount);
    }
}
