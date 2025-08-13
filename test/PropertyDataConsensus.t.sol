// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { PropertyDataConsensus } from "contracts/PropertyDataConsensus.sol";
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
            "PropertyDataConsensus.sol:PropertyDataConsensus", abi.encodeWithSignature("initialize(address)", admin)
        );
        propertyDataConsensus = PropertyDataConsensus(proxy);
    }

    function test_Initialization_ShouldSetDeployerAsAdmin() public view {
        assertTrue(propertyDataConsensus.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_ConsensusLogic_ShouldReachConsensusWhenMinimumSubmissionsMet() public {
        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(propertyHash1, dataGroupHash1, oracle1, dataHash1);
        vm.expectEmit(true, true, true, false);
        emit PropertyDataConsensus.ConsensusReached(propertyHash1, dataGroupHash1, dataHash1, new address[](0));
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash1);
    }

    function test_ConsensusLogic_ShouldUpdateConsensusWhenNewDataHashReachesMinimum() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        vm.prank(oracle3);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(propertyHash1, dataGroupHash1, oracle3, dataHash2);
        vm.expectEmit(true, true, true, false);
        emit PropertyDataConsensus.ConsensusReached(propertyHash1, dataGroupHash1, dataHash2, new address[](0));
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash2);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash2);
    }

    function test_ViewFunctions_GetCurrentFieldDataHash() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(propertyHash1, dataGroupHash1, dataHash1);

        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash1, dataGroupHash1), dataHash1);
        bytes32 propertyHash2 = keccak256("property-789-local-test");
        assertEq(propertyDataConsensus.getCurrentFieldDataHash(propertyHash2, dataGroupHash1), bytes32(0));
    }
}
