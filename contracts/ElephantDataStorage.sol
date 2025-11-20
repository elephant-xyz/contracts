// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Initializable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Placeholder upgradable contract for Elephant data storage.
/// @dev Implementation intentionally left empty until storage schema is defined.
contract ElephantDataStorage is Initializable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer { }

    function _authorizeUpgrade(address) internal override { }
}
