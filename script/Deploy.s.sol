// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Upgrades } from "@openzeppelin-upgrades/Upgrades.sol";
import { VMahout } from "../contracts/VMahout.sol";
import { PropertyDataConsensus } from "../contracts/PropertyDataConsensus.sol";

contract DeployScript is Script {
    function run() external {
        address minter = vm.envAddress("MINTER_ADDRESS");
        address deployer = msg.sender; // Will be the KMS-derived address

        vm.startBroadcast();

        // Deploy VMahout as upgradeable proxy
        address vmahoutProxy = Upgrades.deployUUPSProxy(
            "VMahout.sol",
            abi.encodeCall(VMahout.initialize, (deployer, minter, deployer))
        );

        // Deploy PropertyDataConsensus as upgradeable proxy
        // Initialize with minimum consensus of 3 and deployer as admin
        address consensusProxy = Upgrades.deployUUPSProxy(
            "PropertyDataConsensus.sol",
            abi.encodeCall(PropertyDataConsensus.initialize, (deployer))
        );

        vm.stopBroadcast();

        console.log("VMahout proxy deployed at:", vmahoutProxy);
        console.log("PropertyDataConsensus proxy deployed at:", consensusProxy);

        // Write deployment addresses to file for future upgrades
        string memory deployments = string.concat(
            "VMAHOUT_PROXY=",
            vm.toString(vmahoutProxy),
            "\n",
            "CONSENSUS_PROXY=",
            vm.toString(consensusProxy),
            "\n"
        );
        vm.writeFile(".deployments", deployments);
    }
}
