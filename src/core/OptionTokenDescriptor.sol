// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// libraries
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin/utils/Strings.sol";
// interfaces
import {IOptionTokenDescriptor} from "../interfaces/IOptionTokenDescriptor.sol";

/**
 * @title   OptionTokenDescriptor
 * @author  @antoncoding, @dsshap
 * @dev     While OptionToken is fully permission-less, OptionTokenDescriptor is upgradable and can
 *          be upgraded to a better version to reflect Option position for users.
 */
contract OptionTokenDescriptor is OwnableUpgradeable, UUPSUpgradeable, IOptionTokenDescriptor {
    // solhint-disable-next-line no-empty-blocks
    constructor() initializer {}

    /**
     * @dev init contract and set owner
     */
    function initialize() external initializer {
        __Ownable_init();
    }

    /**
     * @notice return tokenURL for a NFT position
     * @dev we just simply return a static url for now
     */
    function tokenURI(uint256 id) external pure override returns (string memory) {
        return string(abi.encodePacked("https://grappa.finance/token/", Strings.toString(id)));
    }

    /**
     * @dev Upgradable by the owner.
     */
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override {
        _checkOwner();
    }
}
