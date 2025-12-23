// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Mahout } from "../contracts/Mahout.sol";

contract UpgradeMahoutScript is Script {
    error UpgradeMahoutScript__InputInvalid();

    function run() external {
        address proxyAddress = vm.envAddress("MAHOUT_PROXY");

        address defaultAdmin = vm.envOr("DEFAULT_ADMIN_ADDRESS", address(0));
        address minter = vm.envOr("MINTER_ADDRESS", address(0));
        address upgrader = vm.envOr("UPGRADER_ADDRESS", address(0));

        // Prepare initialization data
        bytes memory initData;
        if (upgrader != address(0)) {
            console.log("Preparing initializeV2 call with parameters:");
            console.log("  Default Admin:", defaultAdmin);
            console.log("  Minter:", minter);
            console.log("  Upgrader:", upgrader);

            initData = abi.encodeCall(
                Mahout.initializeV2, (defaultAdmin, minter, upgrader)
            );
        } else {
            console.log("No initialization parameters provided");
            revert UpgradeMahoutScript__InputInvalid();
        }

        vm.startBroadcast();

        address newImpl = address(new Mahout());
        console.log("New implementation deployed at:", newImpl);

        Mahout(proxyAddress).upgradeToAndCall(newImpl, initData);

        vm.stopBroadcast();

        console.log("Mahout upgraded successfully");
        console.log("Proxy:", proxyAddress);
        console.log("New implementation:", newImpl);
    }
}
