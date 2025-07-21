// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades, Options } from "@openzeppelin-upgrades/Upgrades.sol";
import { VMahout } from "../src/VMahout.sol";

contract UpgradeVMahoutScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("VMAHOUT_PROXY");
        address minter = vm.envOr("MINTER_ADDRESS", address(0));

        vm.startBroadcast();

        // Set up options with reference contract
        Options memory opts;
        opts.referenceContract = "VMahout.sol:VMahout";

        // Upgrade the proxy to new implementation
        Upgrades.upgradeProxy(proxyAddress, "VMahout.sol", "", opts);

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
