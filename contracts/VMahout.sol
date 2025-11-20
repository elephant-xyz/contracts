// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Placeholder upgradable contract for the vote token (vMahout).
/// @dev Implementation intentionally left empty until token logic is defined.
contract VMahout is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and sets the owner that can authorize upgrades.
    /// @param initialOwner Address that will control upgrades and own the contract.
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /// @dev Restrict upgrades to the owner set during initialization (can be transferred).
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
