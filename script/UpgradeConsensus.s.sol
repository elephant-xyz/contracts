// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import { PropertyDataConsensus } from "../contracts/PropertyDataConsensus.sol";

contract UpgradeConsensusScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("CONSENSUS_PROXY");

        vm.startBroadcast();

        // Set up options with reference to previous build
        Options memory opts;
        opts.referenceBuildInfoDir = "previous-builds/build-info-v1";
        // Use the Hardhat path format for the reference contract
        opts.referenceContract = "build-info-v1:contracts/PropertyDataConsensus.sol:PropertyDataConsensus";

        // Upgrade the proxy to new implementation
        Upgrades.upgradeProxy(proxyAddress, "PropertyDataConsensus.sol", "", opts);

        vm.stopBroadcast();

        console.log("PropertyDataConsensus upgraded successfully");
    }
}
