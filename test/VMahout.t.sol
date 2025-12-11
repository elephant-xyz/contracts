// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { VMahout } from "contracts/VMahout.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    IAccessControl
} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract VMahoutTest is Test {
    VMahout public vMahout;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public upgrader = makeAddr("upgrader");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function setUp() public {
        bytes memory proxyData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, minter, upgrader
        );
        address proxy = Upgrades.deployUUPSProxy("VMahout.sol", proxyData);
        vMahout = VMahout(proxy);
    }

    function test_Initialization() public view {
        assertEq(vMahout.name(), "vMahout", "Name should be vMahout");
        assertEq(vMahout.symbol(), "VMHT", "Symbol should be VMHT");

        assertTrue(
            vMahout.hasRole(DEFAULT_ADMIN_ROLE, admin), "Admin role not set"
        );
        assertTrue(vMahout.hasRole(MINTER_ROLE, minter), "Minter role not set");
        assertTrue(
            vMahout.hasRole(UPGRADER_ROLE, upgrader), "Upgrader role not set"
        );
    }

    function test_TokenProperties_CannotTransfer() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.transfer(user2, 100);
    }

    function test_TokenProperties_CannotTransferFrom() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.transferFrom(user1, user2, 100);
    }

    function test_TokenProperties_CannotApprove() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.approve(user2, 100);
    }

    function test_Minting_MinterCanMint() public {
        uint256 amount = 1000 ether;
        vm.prank(minter);
        vMahout.mint(user1, amount);
        assertEq(
            vMahout.balanceOf(user1), amount, "Minter should be able to mint"
        );
        assertEq(
            vMahout.totalSupply(), amount, "Total supply should be updated"
        );
    }

    function test_Minting_NonMinterCannotMint() public {
        uint256 amount = 1000 ether;
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                MINTER_ROLE
            )
        );
        vMahout.mint(user1, amount);
    }

    function test_Minting_CorrectAmountMinted() public {
        uint256 firstMintAmount = 500 ether;
        vm.prank(minter);
        vMahout.mint(user1, firstMintAmount);
        assertEq(
            vMahout.balanceOf(user1), firstMintAmount, "First mint incorrect"
        );

        uint256 secondMintAmount = 300 ether;
        vm.prank(minter);
        vMahout.mint(user2, secondMintAmount);
        assertEq(
            vMahout.balanceOf(user2), secondMintAmount, "Second mint incorrect"
        );

        uint256 totalMinted = firstMintAmount + secondMintAmount;
        assertEq(vMahout.totalSupply(), totalMinted, "Total supply incorrect");
    }

    function test_Burning_MinterCanBurn() public {
        vm.prank(minter);
        vMahout.mint(user1, 2 ether);

        vm.prank(minter);
        vMahout.burn(user1, 1 ether);

        assertEq(vMahout.balanceOf(user1), 1 ether, "Balance not reduced");
        assertEq(vMahout.totalSupply(), 1 ether, "Supply not reduced");
    }

    function test_Burning_NonMinterCannotBurn() public {
        vm.prank(minter);
        vMahout.mint(user1, 1 ether);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                MINTER_ROLE
            )
        );
        vMahout.burn(user1, 1 ether);
    }
}
