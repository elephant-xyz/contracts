// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { PropertyDataConsensus } from "contracts/PropertyDataConsensus.sol";
import { VMahout } from "contracts/VMahout.sol";
import { Upgrades } from "@openzeppelin-upgrades/Upgrades.sol";

contract PropertyDataConsensusTest is Test {
    PropertyDataConsensus internal propertyDataConsensus;
    VMahout internal vMahout;

    address internal admin = vm.addr(uint256(keccak256("admin")));
    address internal unprivilegedUser = vm.addr(uint256(keccak256("user")));
    address internal oracle1 = vm.addr(uint256(keccak256("oracle1")));
    address internal oracle2 = vm.addr(uint256(keccak256("oracle2")));
    address internal oracle3 = vm.addr(uint256(keccak256("oracle3")));
    address internal oracle4 = vm.addr(uint256(keccak256("oracle4")));

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant LEXICON_ORACLE_MANAGER_ROLE =
        keccak256("LEXICON_ORACLE_MANAGER_ROLE");
    uint256 internal constant LOCK_DURATION = 7 * 24 * 60;

    bytes32 internal propertyHash1 = sha256("property-123-main-data");
    bytes32 internal propertyHash2 = keccak256("property-456");
    bytes32 internal dataGroupHash1 = sha256("location-coordinates-group");
    bytes32 internal dataHash1 =
        sha256("latitude: 40.7128, longitude: -74.0060");
    bytes32 internal dataHash2 =
        sha256("latitude: 40.7589, longitude: -73.9851");

    function setUp() public {
        vm.prank(admin);
        address proxy = Upgrades.deployUUPSProxy(
            "PropertyDataConsensus.sol:PropertyDataConsensus",
            abi.encodeWithSignature("initialize(address)", admin)
        );
        propertyDataConsensus = PropertyDataConsensus(proxy);

        bytes memory vMahoutData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, admin, admin
        );
        address vMahoutProxy = Upgrades.deployUUPSProxy("VMahout.sol", vMahoutData);
        vMahout = VMahout(vMahoutProxy);

        bytes32 minterRole = vMahout.MINTER_ROLE();
        vm.startPrank(admin);
        vMahout.grantRole(minterRole, address(propertyDataConsensus));
        propertyDataConsensus.setVMahout(address(vMahout));
        vm.stopPrank();
    }

    function test_Initialization_ShouldSetDeployerAsAdmin() public view {
        assertTrue(propertyDataConsensus.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_SubmitData_ShouldStoreCellAndMintOnFirstSubmission() public {
        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(
            propertyHash1, dataGroupHash1, oracle1, dataHash1
        );
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        assertEq(vMahout.balanceOf(oracle1), 1 ether);

        (address oracle,, bytes32 storedHash) =
            _loadDataCell(propertyHash1, dataGroupHash1);
        assertEq(oracle, oracle1);
        assertEq(storedHash, dataHash1);
    }

    function test_SubmitData_ShouldHeartbeatAndNotMintForSameOracle() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        (, uint256 firstTimestamp,) =
            _loadDataCell(propertyHash1, dataGroupHash1);
        vm.warp(block.timestamp + 10);

        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataGroupHeartBeat(
            propertyHash1, dataGroupHash1, oracle1, dataHash1
        );
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        (address oracle, uint256 secondTimestamp,) =
            _loadDataCell(propertyHash1, dataGroupHash1);
        assertEq(oracle, oracle1);
        assertGt(secondTimestamp, firstTimestamp);
        assertEq(vMahout.balanceOf(oracle1), 1 ether);
        assertEq(vMahout.totalSupply(), 1 ether);
    }

    function test_SubmitData_ShouldRevertForDifferentOracleWithinLock() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        vm.warp(block.timestamp + LOCK_DURATION - 1);

        vm.prank(oracle2);
        vm.expectRevert(
            abi.encodeWithSelector(
                PropertyDataConsensus.ElephantProtocol__DataCellLocked.selector,
                propertyHash1,
                dataGroupHash1,
                oracle1
            )
        );
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        (address oracle,,) = _loadDataCell(propertyHash1, dataGroupHash1);
        assertEq(oracle, oracle1);
        assertEq(vMahout.balanceOf(oracle1), 1 ether);
        assertEq(vMahout.balanceOf(oracle2), 0);
    }

    function test_SubmitData_ShouldBurnPreviousOracleAfterLock() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );
        (, uint256 firstTimestamp,) =
            _loadDataCell(propertyHash1, dataGroupHash1);

        vm.warp(block.timestamp + LOCK_DURATION + 1);

        vm.prank(oracle2);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataGroupHeartBeat(
            propertyHash1, dataGroupHash1, oracle2, dataHash1
        );
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        (address oracle, uint256 secondTimestamp,) =
            _loadDataCell(propertyHash1, dataGroupHash1);
        assertEq(oracle, oracle2);
        assertGt(secondTimestamp, firstTimestamp);

        assertEq(vMahout.balanceOf(oracle1), 0);
        assertEq(vMahout.balanceOf(oracle2), 1 ether);
        assertEq(vMahout.totalSupply(), 1 ether);
    }

    function test_SubmitData_ShouldMintWhenDataChanges() public {
        vm.prank(oracle1);
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash1
        );

        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(
            propertyHash1, dataGroupHash1, oracle1, dataHash2
        );
        propertyDataConsensus.submitData(
            propertyHash1, dataGroupHash1, dataHash2
        );

        (address oracle,, bytes32 storedHash) =
            _loadDataCell(propertyHash1, dataGroupHash1);
        assertEq(oracle, oracle1);
        assertEq(storedHash, dataHash2);
        assertEq(vMahout.balanceOf(oracle1), 2 ether);
        assertEq(vMahout.totalSupply(), 2 ether);
    }

    function test_BatchSubmitData_ShouldRewardOnlyNewCells() public {
        PropertyDataConsensus.DataItem[] memory items =
            new PropertyDataConsensus.DataItem[](2);
        items[0] = PropertyDataConsensus.DataItem(
            propertyHash1, dataGroupHash1, dataHash1
        );

        bytes32 dataGroupHash2 = keccak256("size-group");
        bytes32 dataHash3 = keccak256("1500-sqft");
        items[1] = PropertyDataConsensus.DataItem(
            propertyHash2, dataGroupHash2, dataHash3
        );

        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(
            propertyHash1, dataGroupHash1, oracle1, dataHash1
        );
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataSubmitted(
            propertyHash2, dataGroupHash2, oracle1, dataHash3
        );
        propertyDataConsensus.submitBatchData(items);
        assertEq(vMahout.balanceOf(oracle1), 2 ether);

        vm.warp(block.timestamp + 1);
        vm.prank(oracle1);
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataGroupHeartBeat(
            propertyHash1, dataGroupHash1, oracle1, dataHash1
        );
        vm.expectEmit(true, true, true, true);
        emit PropertyDataConsensus.DataGroupHeartBeat(
            propertyHash2, dataGroupHash2, oracle1, dataHash3
        );
        propertyDataConsensus.submitBatchData(items);
        assertEq(vMahout.balanceOf(oracle1), 2 ether);
        assertEq(vMahout.totalSupply(), 2 ether);
    }

    function test_BatchSubmitData_ShouldAllowEmptyBatch() public {
        PropertyDataConsensus.DataItem[] memory items =
            new PropertyDataConsensus.DataItem[](0);

        vm.prank(oracle1);
        propertyDataConsensus.submitBatchData(items);
        assertEq(vMahout.totalSupply(), 0);
    }

    function _loadDataCell(bytes32 propertyHash, bytes32 dataGroupHash)
        internal
        view
        returns (address oracle, uint256 timestamp, bytes32 dataHash)
    {
        bytes32 identifier =
            keccak256(abi.encodePacked(propertyHash, dataGroupHash));
        bytes32 baseSlot =
            keccak256(abi.encode(identifier, uint256(8))); // s_dataCells slot is 8

        oracle = address(
            uint160(uint256(vm.load(address(propertyDataConsensus), baseSlot)))
        );
        timestamp = uint256(
            vm.load(
                address(propertyDataConsensus),
                bytes32(uint256(baseSlot) + 1)
            )
        );
        dataHash = vm.load(
            address(propertyDataConsensus),
            bytes32(uint256(baseSlot) + 2)
        );
    }
}
