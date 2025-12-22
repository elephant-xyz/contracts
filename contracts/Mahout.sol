// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract Mahout is
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 public constant MAX_SUPPLY = 150_000_000 * 10 ** 18;

    error Mahout__MintingImpossible();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address recipient,
        address defaultAdmin,
        address minter,
        address upgrader
    )
        public
        initializer
    {
        __ERC20_init("Mahout", "MHT");
        __AccessControl_init();
        __ERC20Permit_init("Mahout");

        _mint(recipient, 50_000_000 * 10 ** 18);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /// @notice Reinitializer for upgrading from v1 to v2
    /// @dev Used when upgrading from the placeholder contract to the full ERC20 implementation
    /// @param recipient Address that receives the initial token supply
    /// @param defaultAdmin Address that gets DEFAULT_ADMIN_ROLE
    /// @param minter Address that gets MINTER_ROLE
    /// @param upgrader Address that gets UPGRADER_ROLE
    function initializeV2(
        address recipient,
        address defaultAdmin,
        address minter,
        address upgrader
    )
        public
        reinitializer(2)
    {
        __ERC20_init("Mahout", "MHT");
        __AccessControl_init();
        __ERC20Permit_init("Mahout");

        _mint(recipient, 50_000_000 * 10 ** 18);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function mint(
        address to,
        uint256 amount
    )
        public
        onlyRole(MINTER_ROLE)
    {
        if (amount + totalSupply() > MAX_SUPPLY) {
            revert Mahout__MintingImpossible();
        }
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    { }
}
