// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import { Mahout } from "../contracts/Mahout.sol";

contract UpgradeMahoutScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("MAHOUT_PROXY");
        bool skipValidation = vm.envOr("SKIP_VALIDATION", false);
        
        // Get initialization parameters for initializeV2
        // If RECIPIENT_ADDRESS is not set, initData will be empty (no reinitialization)
        address recipient = vm.envOr("RECIPIENT_ADDRESS", address(0));
        address defaultAdmin = vm.envOr("DEFAULT_ADMIN_ADDRESS", address(0));
        address minter = vm.envOr("MINTER_ADDRESS", address(0));
        address upgrader = vm.envOr("UPGRADER_ADDRESS", address(0));
        
        // Prepare initialization data
        bytes memory initData;
        if (recipient != address(0)) {
            console.log("Preparing initializeV2 call with parameters:");
            console.log("  Recipient:", recipient);
            console.log("  Default Admin:", defaultAdmin);
            console.log("  Minter:", minter);
            console.log("  Upgrader:", upgrader);
            
            initData = abi.encodeCall(
                Mahout.initializeV2,
                (recipient, defaultAdmin, minter, upgrader)
            );
        } else {
            console.log("No initialization parameters provided, upgrading without reinitialization");
        }

        vm.startBroadcast();

        // Check if we should skip validation
        bool shouldSkipValidation = skipValidation;

        // Also skip validation if no reference build is available
        try vm.readFile("previous-builds/foundry-v1/.no-reference") {
            console.log("No reference build available, skipping validation...");
            shouldSkipValidation = true;
        } catch {
            // Reference build exists, continue with validation
        }

        if (shouldSkipValidation) {
            console.log("Skipping upgrade validation...");

            // Upgrade without validation
            Options memory opts;
            opts.unsafeSkipAllChecks = true;

            Upgrades.upgradeProxy(proxyAddress, "Mahout.sol:Mahout", initData, opts);
        } else {
            console.log("Using reference build for validation...");
            // Set up options with reference to previous build
            Options memory opts;
            opts.referenceBuildInfoDir = "previous-builds/foundry-v1";
            opts.referenceContract = "foundry-v1:contracts/Mahout.sol:Mahout";

            // Upgrade the proxy to new implementation
            Upgrades.upgradeProxy(proxyAddress, "Mahout.sol:Mahout", initData, opts);
        }

        vm.stopBroadcast();

        console.log("Mahout upgraded successfully");
    }
}
