// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades } from "@openzeppelin-upgrades/Upgrades.sol";
import { PropertyDataConsensus } from "../src/PropertyDataConsensus.sol";

contract UpgradeConsensusScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("CONSENSUS_PROXY");

        vm.startBroadcast();

        // Upgrade the proxy to new implementation
        Upgrades.upgradeProxy(proxyAddress, "PropertyDataConsensus.sol", "");

        vm.stopBroadcast();

        console.log("PropertyDataConsensus upgraded successfully");
    }
}
