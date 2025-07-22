// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import { VMahout } from "../contracts/VMahout.sol";

contract UpgradeVMahoutScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("VMAHOUT_PROXY");
        address minter = vm.envOr("MINTER_ADDRESS", address(0));
        bool skipValidation = vm.envOr("SKIP_VALIDATION", false);

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

            Upgrades.upgradeProxy(proxyAddress, "VMahout.sol:VMahout", "", opts);
        } else {
            console.log("Using reference build for validation...");
            // Set up options with reference to previous build
            Options memory opts;
            opts.referenceBuildInfoDir = "previous-builds/foundry-v1";
            opts.referenceContract = "foundry-v1:contracts/VMahout.sol:VMahout";

            // Upgrade the proxy to new implementation
            Upgrades.upgradeProxy(proxyAddress, "VMahout.sol:VMahout", "", opts);
        }

        // Grant MINTER_ROLE if minter address provided
        if (minter != address(0)) {
            VMahout vmahout = VMahout(proxyAddress);
            bytes32 MINTER_ROLE = vmahout.MINTER_ROLE();
            vmahout.grantRole(MINTER_ROLE, minter);
            console.log("MINTER_ROLE granted to:", minter);
        }

        vm.stopBroadcast();

        console.log("VMahout upgraded successfully");
    }
}
