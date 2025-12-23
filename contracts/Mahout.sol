// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

/// @custom:oz-upgrades-unsafe-skip

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
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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
    /// @dev Used when upgrading from the placeholder contract to the full ERC20 implementation and mint initial tokens.
    /// @param defaultAdmin Address that gets DEFAULT_ADMIN_ROLE
    /// @param minter Address that gets MINTER_ROLE
    /// @param upgrader Address that gets UPGRADER_ROLE
    function initializeV2(
        address defaultAdmin,
        address minter,
        address upgrader
    )
        public
        reinitializer(2)
    {
        require(
            defaultAdmin != address(0), "Mahout: defaultAdmin is zero address"
        );
        require(minter != address(0), "Mahout: minter is zero address");
        require(upgrader != address(0), "Mahout: upgrader is zero address");
        __ERC20_init("Mahout", "MHT");
        __AccessControl_init();
        __ERC20Permit_init("Mahout");

        _mint(0xBc746D0AEeEb3c739AA59621D01ffAcE7946BE74, 31_818_182 * 10 ** 18);
        _mint(0x0000000000000000000000000000000000000000, 6_595_238 * 10 ** 18);
        _mint(0x0000000000000000000000000000000000000000, 6_595_238 * 10 ** 18);
        _mint(0x12292e9FB05c75c53681366e604EA9E057fC7b89, 2_727_273 * 10 ** 18);
        _mint(0x8e46E2bff0c5ED89447b5d64c4055daFda88dE16, 909_091 * 10 ** 18);
        _mint(0x797D6fbdd6A84137CBaFC56f2203242BBc2839C1, 909_091 * 10 ** 18);
        _mint(0xc54B0C869D7670E1A66223C5090cC74a3f7Bf7A9, 303_030 * 10 ** 18);
        _mint(0x0000000000000000000000000000000000000000, 142_857 * 10 ** 18);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
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
