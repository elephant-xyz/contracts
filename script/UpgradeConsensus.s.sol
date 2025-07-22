// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import { PropertyDataConsensus } from "../contracts/PropertyDataConsensus.sol";

contract UpgradeConsensusScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("CONSENSUS_PROXY");
        bool skipValidation = vm.envOr("SKIP_VALIDATION", false);

        vm.startBroadcast();

        if (skipValidation) {
            console.log("Skipping upgrade validation...");

            // Upgrade without validation
            Options memory opts;
            opts.unsafeSkipAllChecks = true;

            Upgrades.upgradeProxy(proxyAddress, "PropertyDataConsensus.sol:PropertyDataConsensus", "", opts);
        } else {
            // Set up options with reference to previous build
            Options memory opts;
            opts.referenceBuildInfoDir = "previous-builds/foundry-v1";
            opts.referenceContract = "foundry-v1:contracts/PropertyDataConsensus.sol:PropertyDataConsensus";

            // Upgrade the proxy to new implementation
            Upgrades.upgradeProxy(proxyAddress, "PropertyDataConsensus.sol:PropertyDataConsensus", "", opts);
        }

        vm.stopBroadcast();

        console.log("PropertyDataConsensus upgraded successfully");
    }
}
