// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { PropertyDataConsensus, IPropertyDataConsensus } from "contracts/PropertyDataConsensus.sol";
import "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Upgrades } from "@openzeppelin-upgrades/Upgrades.sol";

contract PropertyDataConsensusTest is Test {
    PropertyDataConsensus internal propertyDataConsensus;

    address internal admin = vm.addr(uint256(keccak256("admin")));
    address internal unprivilegedUser = vm.addr(uint256(keccak256("user")));
    address internal oracle1 = vm.addr(uint256(keccak256("oracle1")));
    address internal oracle2 = vm.addr(uint256(keccak256("oracle2")));
    address internal oracle3 = vm.addr(uint256(keccak256("oracle3")));
    address internal oracle4 = vm.addr(uint256(keccak256("oracle4")));

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant LEXICON_ORACLE_MANAGER_ROLE = keccak256("LEXICON_ORACLE_MANAGER_ROLE");

    bytes32 internal propertyHash1 = sha256("property-123-main-data");
    bytes32 internal dataGroupHash1 = sha256("location-coordinates-group");
    bytes32 internal dataHash1 = sha256("latitude: 40.7128, longitude: -74.0060");
    bytes32 internal dataHash2 = sha256("latitude: 40.7589, longitude: -73.9851");

    function setUp() public {
        vm.prank(admin);
        address proxy = Upgrades.deployUUPSProxy(
            "PropertyDataConsensus.sol:PropertyDataConsensus",
            abi.encodeWithSignature("initialize(uint256,address)", 3, admin)
        );
        propertyDataConsensus = PropertyDataConsensus(proxy);
    }

    function test_Initialization_ShouldSetDeployerAsAdmin() public view {
        assertTrue(propertyDataConsensus.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_Initialization_ShouldSetInitialMinimumConsensus() public view {
        assertEq(propertyDataConsensus.minimumConsensus(), 3);
    }

    function test_Initialization_ShouldSetMinimumConsensusTo3IfInitializedWithLessThan3() public {
        vm.prank(admin);
        address proxy = Upgrades.deployUUPSProxy(
            "PropertyDataConsensus.sol:PropertyDataConsensus",
            abi.encodeWithSignature("initialize(uint256,address)", 1, admin)
        );
        PropertyDataConsensus newConsensus = PropertyDataConsensus(proxy);
        assertEq(newConsensus.minimumConsensus(), 3);
    }

    function test_Initialization_ShouldNotAllowReInitialization() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        propertyDataConsensus.initialize(3, unprivilegedUser);
    }

    function test_UpdateMinimumConsensus_ShouldAllowAdminToUpdate() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.MinimumConsensusUpdated(3, 4);
        propertyDataConsensus.updateMinimumConsensus(4);
        assertEq(propertyDataConsensus.minimumConsensus(), 4);
    }

    function test_UpdateMinimumConsensus_ShouldPreventNonAdminUpdate() public {
        vm.prank(unprivilegedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unprivilegedUser, DEFAULT_ADMIN_ROLE
            )
        );
        propertyDataConsensus.updateMinimumConsensus(5);
    }

    function test_UpdateMinimumConsensus_ShouldRevertIfNewMinimumIsLessThan3() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(PropertyDataConsensus.InvalidMinimumConsensus.selector, 2));
        propertyDataConsensus.updateMinimumConsensus(2);
    }

    function test_ConsensusLogic_ShouldReachConsensusWhenMinimumSubmissionsMet() public {
        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataSubmitted(propertyHash1, dataGroupHash1, oracle1, dataHash1);
        vm.expectEmit(true, true, true, false);
        emit IPropertyDataConsensus.ConsensusReached(propertyHash1, dataGroupHash1, dataHash1, new address[](0));
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash1);
        IPropertyDataConsensus.DataVersion[] memory dataVesion =
            propertyDataConsensus.getConsensusHistory(propertyHash1, dataGroupHash1);
        assertEq(dataVesion[dataVesion.length - 1].dataHash, dataHash1);
        assertEq(dataVesion[dataVesion.length - 1].oracles.length, 1);
    }

    function test_ConsensusLogic_ShouldUpdateConsensusWhenNewDataHashReachesMinimum() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        vm.prank(oracle3);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataSubmitted(propertyHash1, dataGroupHash1, oracle3, dataHash2);
        vm.expectEmit(true, true, true, false);
        emit IPropertyDataConsensus.ConsensusReached(propertyHash1, dataGroupHash1, dataHash2, new address[](0));
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash2);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash2);
        IPropertyDataConsensus.DataVersion[] memory dataVesion =
            propertyDataConsensus.getConsensusHistory(propertyHash1, dataGroupHash1);
        assertEq(dataVesion[dataVesion.length - 1].dataHash, dataHash2);
    }

    function test_ViewFunctions_GetCurrentFieldDataHash() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash1);
        bytes32 propertyHash2 = keccak256("property-789-local-test");
        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash2, dataGroupHash1), bytes32(0));
    }

    function test_ViewFunctions_GetSubmitterCountForDataHash() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getSubmitterCountForDataHash(propertyHash1, dataGroupHash1, dataHash1), 1);
        assertEq(propertyDataConsensus.getSubmitterCountForDataHash(propertyHash1, dataGroupHash1, dataHash2), 0);
    }

    function test_ViewFunctions_GetConsensusHistory() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        IPropertyDataConsensus.DataVersion[] memory dataVesion =
            propertyDataConsensus.getConsensusHistory(propertyHash1, dataGroupHash1);
        assertEq(dataVesion[dataVesion.length - 1].dataHash, dataHash1);
    }

    function test_ViewFunctions_GetParticipantsForConsensusDataHash() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        address[] memory participants =
            propertyDataConsensus.getParticipantsForConsensusDataHash(propertyHash1, dataGroupHash1, dataHash1);
        assertEq(participants.length, 1);
        assertEq(participants[0], oracle1);
    }

    function test_ViewFunctions_GetParticipantsForConsensusDataHash_RevertIfNoConsensus() public {
        bytes32 propertyHashFieldHash = keccak256(abi.encodePacked(propertyHash1, dataGroupHash1));
        vm.expectRevert(
            abi.encodeWithSelector(
                PropertyDataConsensus.NoConsensusReachedForDataHash.selector, propertyHashFieldHash, dataHash2
            )
        );
        propertyDataConsensus.getParticipantsForConsensusDataHash(propertyHash1, dataGroupHash1, dataHash2);
    }

    function test_ViewFunctions_GetCurrentConsensusParticipants() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        address[] memory participants =
            propertyDataConsensus.getCurrentConsensusParticipants(propertyHash1, dataGroupHash1);
        assertEq(participants.length, 1);
    }

    function test_ViewFunctions_GetCurrentConsensusParticipants_ReturnEmptyIfNoConsensus() public view {
        bytes32 propertyHash2 = keccak256("property-999-current-test");
        address[] memory participants =
            propertyDataConsensus.getCurrentConsensusParticipants(propertyHash2, dataGroupHash1);
        assertEq(participants.length, 0);
    }

    function test_ViewFunctions_HasUserSubmittedDataHash() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertTrue(propertyDataConsensus.hasUserSubmittedDataHash(propertyHash1, dataGroupHash1, dataHash1, oracle1));
        assertFalse(propertyDataConsensus.hasUserSubmittedDataHash(propertyHash1, dataGroupHash1, dataHash2, oracle1));
        assertFalse(
            propertyDataConsensus.hasUserSubmittedDataHash(propertyHash1, dataGroupHash1, dataHash1, unprivilegedUser)
        );
    }

    function test_ConfigurableConsensus_SetConsensusRequired() public {
        vm.prank(admin);
        propertyDataConsensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, admin);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataGroupConsensusUpdated(dataGroupHash1, 0, 5);
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 5);

        assertEq(propertyDataConsensus.consensusRequired(dataGroupHash1), 5);
    }

    function test_ConfigurableConsensus_EmitEventWhenUpdating() public {
        vm.startPrank(admin);
        propertyDataConsensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, admin);
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 5);

        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataGroupConsensusUpdated(dataGroupHash1, 5, 7);
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 7);
        vm.stopPrank();
    }

    function test_ConfigurableConsensus_PreventNonManagerFromSetting() public {
        vm.prank(unprivilegedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unprivilegedUser, LEXICON_ORACLE_MANAGER_ROLE
            )
        );
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 5);
    }

    function test_ConfigurableConsensus_ShouldNotReachConsensusWith3SubmissionsWhenThresholdIs4() public {
        vm.startPrank(admin);
        propertyDataConsensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, admin);
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 4);
        vm.stopPrank();

        bytes32 propertyHash2 = keccak256("property-456-main-data");

        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash2, dataGroupHash1, dataHash1);

        // With immediate update, current field is set on first submission regardless of threshold
        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash2, dataGroupHash1), dataHash1);
    }

    function test_ConfigurableConsensus_ShouldReachConsensusWith4SubmissionsWhenThresholdIs4() public {
        vm.startPrank(admin);
        propertyDataConsensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, admin);
        propertyDataConsensus.setConsensusRequired(dataGroupHash1, 4);
        vm.stopPrank();

        bytes32 propertyHash3 = keccak256("property-789-main-data");

        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataSubmitted(propertyHash3, dataGroupHash1, oracle1, dataHash1);
        vm.expectEmit(true, true, true, false);
        emit IPropertyDataConsensus.ConsensusReached(propertyHash3, dataGroupHash1, dataHash1, new address[](0));
        propertyDataConsensus.submitData(propertyHash3, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash3, dataGroupHash1), dataHash1);
    }

    function test_ConfigurableConsensus_ShouldUseDefaultConsensusForOtherGroups() public {
        bytes32 dataGroupHash2 = keccak256("property-details-group");

        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit IPropertyDataConsensus.DataSubmitted(propertyHash1, dataGroupHash2, oracle1, dataHash1);
        vm.expectEmit(true, true, true, false);
        emit IPropertyDataConsensus.ConsensusReached(propertyHash1, dataGroupHash2, dataHash1, new address[](0));
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash2, dataHash1);
    }
}
