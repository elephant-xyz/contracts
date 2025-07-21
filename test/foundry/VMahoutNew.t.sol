// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/VMahout.sol";
import "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import "@openzeppelin-upgrades/Upgrades.sol";

contract VMahoutNewTest is Test {
    VMahout internal vMahout;

    address internal admin = address(0x1);
    address internal minter = address(0x2);
    address internal upgrader = address(0x3);
    address internal user1 = address(0x4);
    address internal user2 = address(0x5);

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function setUp() public {
        vm.prank(admin);
        address proxy = Upgrades.deployUUPSProxy(
            "VMahout.sol",
            abi.encodeWithSignature("initialize(address,address,address)", admin, minter, upgrader)
        );
        vMahout = VMahout(proxy);
    }

    function test_Initialization_ShouldInitializeWithCorrectNameAndSymbol() public {
        assertEq(vMahout.name(), "vMahout");
        assertEq(vMahout.symbol(), "VMHT");
    }

    function test_Initialization_ShouldSetCorrectRoles() public {
        assertTrue(vMahout.hasRole(vMahout.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vMahout.hasRole(MINTER_ROLE, minter));
        assertTrue(vMahout.hasRole(UPGRADER_ROLE, upgrader));
    }

    function test_TokenProperties_ShouldPreventTransfers() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.transfer(user2, 100);
    }

    function test_TokenProperties_ShouldPreventTransferFrom() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.transferFrom(admin, user2, 100);
    }

    function test_TokenProperties_ShouldPreventApprovals() public {
        vm.prank(user1);
        vm.expectRevert(VMahout.VMahout__TransferNotAllowed.selector);
        vMahout.approve(user2, 100);
    }

    

    function test_MintingLogic_ShouldAllowMinterToMint() public {
        uint256 amount = 1000 ether;
        vm.prank(minter);
        vMahout.mint(user1, amount);
        assertEq(vMahout.balanceOf(user1), amount);
        assertEq(vMahout.totalSupply(), amount);
    }

    function test_MintingLogic_ShouldNotAllowNonMinterToMint() public {
        uint256 amount = 1000 ether;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, MINTER_ROLE));
        vMahout.mint(user1, amount);
    }

    function test_MintingLogic_ShouldMintCorrectAmount() public {
        uint256 firstMintAmount = 500 ether;
        vm.prank(minter);
        vMahout.mint(user1, firstMintAmount);
        assertEq(vMahout.balanceOf(user1), firstMintAmount);

        uint256 secondMintAmount = 300 ether;
        vm.prank(minter);
        vMahout.mint(user2, secondMintAmount);
        assertEq(vMahout.balanceOf(user2), secondMintAmount);

        uint256 totalMinted = firstMintAmount + secondMintAmount;
        assertEq(vMahout.totalSupply(), totalMinted);
    }
}
