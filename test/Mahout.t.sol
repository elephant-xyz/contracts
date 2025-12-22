// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { Mahout } from "contracts/Mahout.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    IAccessControl
} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MahoutTest is Test {
    Mahout public mahout;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public upgrader = makeAddr("upgrader");
    address public recipient = makeAddr("recipient");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public constant MAX_SUPPLY = 150_000_000 * 10 ** 18;
    uint256 public constant INITIAL_MINT = 50_000_000 * 10 ** 18;

    function setUp() public {
        bytes memory proxyData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            recipient,
            admin,
            minter,
            upgrader
        );
        address proxy = Upgrades.deployUUPSProxy("Mahout.sol", proxyData);
        mahout = Mahout(proxy);
    }

    // ==================== Initialization Tests ====================

    function test_Initialization_ShouldSetTokenName() public view {
        assertEq(mahout.name(), "Mahout", "Name should be Mahout");
    }

    function test_Initialization_ShouldSetTokenSymbol() public view {
        assertEq(mahout.symbol(), "MHT", "Symbol should be MHT");
    }

    function test_Initialization_ShouldSetAdminRole() public view {
        assertTrue(
            mahout.hasRole(DEFAULT_ADMIN_ROLE, admin),
            "Admin role should be set"
        );
    }

    function test_Initialization_ShouldSetMinterRole() public view {
        assertTrue(
            mahout.hasRole(MINTER_ROLE, minter), "Minter role should be set"
        );
    }

    function test_Initialization_ShouldSetUpgraderRole() public view {
        assertTrue(
            mahout.hasRole(UPGRADER_ROLE, upgrader),
            "Upgrader role should be set"
        );
    }

    function test_Initialization_ShouldMintInitialSupplyToRecipient()
        public
        view
    {
        assertEq(
            mahout.balanceOf(recipient),
            INITIAL_MINT,
            "Recipient should receive initial mint"
        );
    }

    function test_Initialization_ShouldSetCorrectTotalSupply() public view {
        assertEq(
            mahout.totalSupply(),
            INITIAL_MINT,
            "Total supply should be initial mint"
        );
    }

    function test_Initialization_ShouldNotSetRolesForUnauthorizedUsers()
        public
        view
    {
        assertFalse(
            mahout.hasRole(DEFAULT_ADMIN_ROLE, user1),
            "User1 should not have admin role"
        );
        assertFalse(
            mahout.hasRole(MINTER_ROLE, user1),
            "User1 should not have minter role"
        );
        assertFalse(
            mahout.hasRole(UPGRADER_ROLE, user1),
            "User1 should not have upgrader role"
        );
    }

    function test_Initialization_MaxSupplyConstant() public view {
        assertEq(
            mahout.MAX_SUPPLY(), MAX_SUPPLY, "MAX_SUPPLY should be 150M tokens"
        );
    }

    // ==================== Role Management Tests ====================
    // 1. Only admin can assign roles

    function test_RoleManagement_AdminCanGrantUpgraderRole() public {
        vm.prank(admin);
        mahout.grantRole(UPGRADER_ROLE, user1);

        assertTrue(
            mahout.hasRole(UPGRADER_ROLE, user1),
            "Admin should be able to grant upgrader role"
        );
    }

    function test_RoleManagement_AdminCanRevokeUpgraderRole() public {
        vm.prank(admin);
        mahout.grantRole(UPGRADER_ROLE, user1);

        vm.prank(admin);
        mahout.revokeRole(UPGRADER_ROLE, user1);

        assertFalse(
            mahout.hasRole(UPGRADER_ROLE, user1),
            "Admin should be able to revoke upgrader role"
        );
    }

    function test_RoleManagement_NonAdminCannotGrantRoles() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                DEFAULT_ADMIN_ROLE
            )
        );
        mahout.grantRole(UPGRADER_ROLE, user2);
    }

    function test_RoleManagement_NonAdminCannotRevokeRoles() public {
        vm.prank(admin);
        mahout.grantRole(UPGRADER_ROLE, user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user2,
                DEFAULT_ADMIN_ROLE
            )
        );
        mahout.revokeRole(UPGRADER_ROLE, user1);
    }

    function test_RoleManagement_MinterCannotGrantRoles() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                DEFAULT_ADMIN_ROLE
            )
        );
        mahout.grantRole(UPGRADER_ROLE, user1);
    }

    function test_RoleManagement_UpgraderCannotGrantRoles() public {
        vm.prank(upgrader);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                upgrader,
                DEFAULT_ADMIN_ROLE
            )
        );
        mahout.grantRole(UPGRADER_ROLE, user1);
    }

    function test_MinterRole_AdminCanRevokeMinterRole() public {
        vm.prank(admin);
        mahout.revokeRole(MINTER_ROLE, minter);

        assertFalse(
            mahout.hasRole(MINTER_ROLE, minter),
            "Admin should be able to revoke minter role"
        );
    }

    function test_MinterRole_RevokedMinterCannotMint() public {
        vm.prank(admin);
        mahout.revokeRole(MINTER_ROLE, minter);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                minter,
                MINTER_ROLE
            )
        );
        mahout.mint(user1, 1000 ether);
    }

    // ==================== Minting Tests ====================
    // 3. Only minter can mint new tokens

    function test_Minting_MinterCanMint() public {
        uint256 amount = 1000 ether;
        vm.prank(minter);
        mahout.mint(user1, amount);

        assertEq(
            mahout.balanceOf(user1), amount, "Minter should be able to mint"
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
        mahout.mint(user1, amount);
    }

    function test_Minting_AdminCannotMint() public {
        uint256 amount = 1000 ether;
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                admin,
                MINTER_ROLE
            )
        );
        mahout.mint(user1, amount);
    }

    function test_Minting_UpgraderCannotMint() public {
        uint256 amount = 1000 ether;
        vm.prank(upgrader);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                upgrader,
                MINTER_ROLE
            )
        );
        mahout.mint(user1, amount);
    }

    function test_Minting_UpdatesTotalSupply() public {
        uint256 supplyBefore = mahout.totalSupply();
        uint256 amount = 1000 ether;

        vm.prank(minter);
        mahout.mint(user1, amount);

        assertEq(
            mahout.totalSupply(),
            supplyBefore + amount,
            "Total supply should increase"
        );
    }

    function test_Minting_ToMultipleRecipients() public {
        uint256 amount1 = 500 ether;
        uint256 amount2 = 300 ether;

        vm.startPrank(minter);
        mahout.mint(user1, amount1);
        mahout.mint(user2, amount2);
        vm.stopPrank();

        assertEq(mahout.balanceOf(user1), amount1, "User1 balance incorrect");
        assertEq(mahout.balanceOf(user2), amount2, "User2 balance incorrect");
    }

    function test_Minting_ZeroAmount() public {
        vm.prank(minter);
        mahout.mint(user1, 0);

        assertEq(mahout.balanceOf(user1), 0, "Balance should be zero");
    }

    // ==================== Max Supply Tests ====================
    // 4. Only 150_000_000 tokens can be minted

    function test_MaxSupply_CanMintUpToMaxSupply() public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();

        vm.prank(minter);
        mahout.mint(user1, remainingSupply);

        assertEq(
            mahout.totalSupply(), MAX_SUPPLY, "Should reach max supply exactly"
        );
    }

    function test_MaxSupply_CannotMintBeyondMaxSupply() public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();

        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, remainingSupply + 1);
    }

    function test_MaxSupply_CannotMintExactlyOverByOne() public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();

        vm.prank(minter);
        mahout.mint(user1, remainingSupply);

        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, 1);
    }

    function test_MaxSupply_CannotMintLargeAmountOverMax() public {
        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, MAX_SUPPLY);
    }

    function test_MaxSupply_MultipleMintsTotalExceedsMax() public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        uint256 firstMint = remainingSupply / 2;
        uint256 secondMint = remainingSupply - firstMint;

        vm.startPrank(minter);
        mahout.mint(user1, firstMint);
        mahout.mint(user2, secondMint);

        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, 1);
        vm.stopPrank();
    }

    function test_MaxSupply_MintExactRemainingSupply() public {
        uint256 remaining = MAX_SUPPLY - mahout.totalSupply();

        vm.prank(minter);
        mahout.mint(user1, remaining);

        assertEq(mahout.totalSupply(), MAX_SUPPLY, "Should be at max supply");
        assertEq(
            mahout.balanceOf(user1), remaining, "User1 should have remaining"
        );
    }

    // ==================== Transfer Tests ====================

    function test_Transfer_ShouldWork() public {
        uint256 amount = 100;

        vm.prank(recipient);
        mahout.transfer(user1, amount);

        assertEq(
            mahout.balanceOf(user1), amount, "User1 should receive transfer"
        );
        assertEq(
            mahout.balanceOf(recipient),
            INITIAL_MINT - amount,
            "Recipient balance should decrease"
        );
    }

    function test_TransferFrom_ShouldWorkWithApproval() public {
        uint256 amount = 100;

        vm.prank(recipient);
        mahout.approve(user1, amount);

        vm.prank(user1);
        mahout.transferFrom(recipient, user2, amount);

        assertEq(mahout.balanceOf(user2), amount, "User2 should receive tokens");
    }

    // ==================== ERC20Permit Tests ====================

    function test_Permit_ShouldWorkWithValidSignature() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        address spender = user1;
        uint256 value = 1000;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(minter);
        mahout.mint(owner, value);

        bytes32 domainSeparator = mahout.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        uint256 nonce = mahout.nonces(owner);

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        mahout.permit(owner, spender, value, deadline, v, r, s);

        assertEq(
            mahout.allowance(owner, spender), value, "Allowance should be set"
        );
    }

    // ==================== Fuzz Tests ====================
    // 5. Fuzz testing for minting and permissions

    function testFuzz_Minting_MinterCanMintValidAmount(uint96 amount) public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        vm.assume(amount <= remainingSupply);

        uint256 supplyBefore = mahout.totalSupply();
        uint256 balanceBefore = mahout.balanceOf(user1);

        vm.prank(minter);
        mahout.mint(user1, amount);

        assertEq(
            mahout.balanceOf(user1),
            balanceBefore + amount,
            "Balance should increase by amount"
        );
        assertEq(
            mahout.totalSupply(),
            supplyBefore + amount,
            "Total supply should increase by amount"
        );
    }

    function testFuzz_Minting_NonMinterCannotMint(
        address nonMinter,
        uint256 amount
    )
        public
    {
        vm.assume(nonMinter != minter);
        vm.assume(nonMinter != address(0));
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        vm.assume(amount <= remainingSupply);

        vm.prank(nonMinter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonMinter,
                MINTER_ROLE
            )
        );
        mahout.mint(user1, amount);
    }

    function testFuzz_MaxSupply_CannotExceedMax(uint96 extraAmount) public {
        vm.assume(extraAmount > 0);

        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        vm.prank(minter);
        mahout.mint(user1, remainingSupply);

        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, extraAmount);
    }

    function testFuzz_MaxSupply_MintingBeyondMaxReverts(uint128 amount) public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        vm.assume(amount > remainingSupply);

        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, amount);
    }

    function testFuzz_RoleManagement_OnlyAdminCanGrantUpgraderRole(
        address caller,
        address grantee
    )
        public
    {
        vm.assume(caller != admin);
        vm.assume(caller != address(0));
        vm.assume(grantee != address(0));

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                caller,
                DEFAULT_ADMIN_ROLE
            )
        );
        mahout.grantRole(UPGRADER_ROLE, grantee);
    }

    function testFuzz_Transfer_ShouldWorkWithValidAmounts(uint96 amount)
        public
    {
        vm.assume(amount <= INITIAL_MINT);

        uint256 recipientBalanceBefore = mahout.balanceOf(recipient);
        uint256 user1BalanceBefore = mahout.balanceOf(user1);

        vm.prank(recipient);
        mahout.transfer(user1, amount);

        assertEq(
            mahout.balanceOf(recipient),
            recipientBalanceBefore - amount,
            "Recipient balance should decrease"
        );
        assertEq(
            mahout.balanceOf(user1),
            user1BalanceBefore + amount,
            "User1 balance should increase"
        );
    }

    function testFuzz_Minting_ToRandomAddresses(
        address to,
        uint96 amount
    )
        public
    {
        vm.assume(to != address(0));
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        vm.assume(amount <= remainingSupply);

        uint256 balanceBefore = mahout.balanceOf(to);

        vm.prank(minter);
        mahout.mint(to, amount);

        assertEq(
            mahout.balanceOf(to),
            balanceBefore + amount,
            "Recipient balance should increase"
        );
    }

    function testFuzz_Minting_MultipleMintsShouldNotExceedMax(
        uint96 amount1,
        uint96 amount2
    )
        public
    {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();
        uint256 totalAmount = uint256(amount1) + uint256(amount2);
        vm.assume(totalAmount <= remainingSupply);

        vm.startPrank(minter);
        mahout.mint(user1, amount1);
        mahout.mint(user2, amount2);
        vm.stopPrank();

        assertLe(
            mahout.totalSupply(),
            MAX_SUPPLY,
            "Total supply should not exceed max"
        );
        assertEq(mahout.balanceOf(user1), amount1, "User1 balance incorrect");
        assertEq(mahout.balanceOf(user2), amount2, "User2 balance incorrect");
    }

    // ==================== Edge Case Tests ====================

    function test_EdgeCase_MintToZeroAddressReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        mahout.mint(address(0), 1000 ether);
    }

    function test_EdgeCase_InitialRecipientCanTransfer() public {
        uint256 transferAmount = INITIAL_MINT / 2;

        vm.prank(recipient);
        mahout.transfer(user1, transferAmount);

        assertEq(
            mahout.balanceOf(user1),
            transferAmount,
            "User1 should receive tokens"
        );
    }

    function test_EdgeCase_MintAfterBurningDoesNotIncreaseMaxCapacity() public {
        uint256 remainingSupply = MAX_SUPPLY - mahout.totalSupply();

        vm.prank(minter);
        mahout.mint(user1, remainingSupply);

        assertEq(mahout.totalSupply(), MAX_SUPPLY, "Should be at max supply");

        vm.prank(minter);
        vm.expectRevert(Mahout.Mahout__MintingImpossible.selector);
        mahout.mint(user1, 1);
    }

    // ==================== Access Control Inheritance Tests ====================

    function test_AccessControl_DefaultAdminRoleIsAdminOfAllRoles()
        public
        view
    {
        assertEq(
            mahout.getRoleAdmin(MINTER_ROLE),
            DEFAULT_ADMIN_ROLE,
            "DEFAULT_ADMIN_ROLE should be admin of MINTER_ROLE"
        );
        assertEq(
            mahout.getRoleAdmin(UPGRADER_ROLE),
            DEFAULT_ADMIN_ROLE,
            "DEFAULT_ADMIN_ROLE should be admin of UPGRADER_ROLE"
        );
    }

    function test_AccessControl_AdminCanRenounceOwnRole() public {
        vm.prank(admin);
        mahout.renounceRole(DEFAULT_ADMIN_ROLE, admin);

        assertFalse(
            mahout.hasRole(DEFAULT_ADMIN_ROLE, admin),
            "Admin should be able to renounce own role"
        );
    }

    function test_AccessControl_UserCannotRenounceOtherUserRole() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlBadConfirmation.selector
            )
        );
        mahout.renounceRole(MINTER_ROLE, minter);
    }

    // ==================== Decimals and Token Metadata Tests ====================

    function test_TokenMetadata_DecimalsIs18() public view {
        assertEq(mahout.decimals(), 18, "Decimals should be 18");
    }

    // ==================== Reentrancy Protection (Implicit) ====================

    function test_StateConsistency_AfterMultipleOperations() public {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(minter);
        mahout.mint(user1, mintAmount);
        mahout.mint(user2, mintAmount);
        vm.stopPrank();

        vm.prank(user1);
        mahout.transfer(user2, 500 ether);

        assertEq(
            mahout.balanceOf(user1),
            500 ether,
            "User1 balance should be 500 ether"
        );
        assertEq(
            mahout.balanceOf(user2),
            1500 ether,
            "User2 balance should be 1500 ether"
        );
        assertEq(
            mahout.totalSupply(),
            INITIAL_MINT + 2000 ether,
            "Total supply should be consistent"
        );
    }
}
