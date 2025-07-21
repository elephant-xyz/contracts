// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PropertyDataConsensus } from "contracts/PropertyDataConsensus.sol";

contract GrantRolesScript is Script {
    bytes32 public constant LEXICON_ORACLE_MANAGER_ROLE = keccak256("LEXICON_ORACLE_MANAGER_ROLE");

    function run() external {
        address proxyAddress = vm.envAddress("CONSENSUS_PROXY");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");

        console.log("Granting LEXICON_ORACLE_MANAGER_ROLE to:", recipient);
        console.log("On PropertyDataConsensus proxy:", proxyAddress);

        vm.startBroadcast();

        PropertyDataConsensus consensus = PropertyDataConsensus(proxyAddress);

        // Grant the role
        consensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, recipient);

        console.log("Role granted successfully!");

        // Verify the role was granted
        bool hasRole = consensus.hasRole(LEXICON_ORACLE_MANAGER_ROLE, recipient);
        console.log("Verification - Has role:", hasRole);

        vm.stopBroadcast();
    }
}
