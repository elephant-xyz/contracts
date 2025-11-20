// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { VMahout } from "../contracts/VMahout.sol";
import { Mahout } from "../contracts/Mahout.sol";
import { ElephantDataStorage } from "../contracts/ElephantDataStorage.sol";

contract DeployScript is Script {
    bytes32 internal constant SALT_VMAHOUT =
        keccak256(abi.encodePacked("VMahout"));
    bytes32 internal constant SALT_MAHOUT =
        keccak256(abi.encodePacked("Mahout"));
    bytes32 internal constant SALT_STORAGE =
        keccak256(abi.encodePacked("ElephantDataStorage"));

    function run() external {
        vm.startBroadcast();

        // Default owner = broadcasting key; set OWNER env var to override.
        address owner = _getOwner();

        address vImpl = address(new VMahout());
        address mImpl = address(new Mahout());
        address sImpl = address(new ElephantDataStorage());

        address vProxy = _deployDeterministic(
            vImpl, abi.encodeCall(VMahout.initialize, (owner)), SALT_VMAHOUT
        );

        address mProxy = _deployDeterministic(
            mImpl, abi.encodeCall(Mahout.initialize, (owner)), SALT_MAHOUT
        );

        address storageProxy = _deployDeterministic(
            sImpl,
            abi.encodeCall(ElephantDataStorage.initialize, (owner)),
            SALT_STORAGE
        );

        vm.stopBroadcast();

        console.log("VMahout proxy", vProxy);
        console.log("Mahout proxy", mProxy);
        console.log("ElephantDataStorage proxy", storageProxy);

        string memory deployments = string.concat(
            "VMAHOUT_PROXY=",
            vm.toString(vProxy),
            "\n",
            "MAHOUT_PROXY=",
            vm.toString(mProxy),
            "\n",
            "STORAGE_PROXY=",
            vm.toString(storageProxy),
            "\n"
        );
    }

    function _getOwner() internal view returns (address) {
        // forge-std returns zero if env var is unset; fallback to tx.origin.
        address envOwner = vm.envOr("OWNER", address(0));
        return envOwner == address(0) ? tx.origin : envOwner;
    }

    function _deployDeterministic(
        address implementation,
        bytes memory initData,
        bytes32 salt
    )
        internal
        returns (address deployed)
    {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );

        address predicted = Create2.computeAddress(
            salt, keccak256(bytecode), CREATE2_FACTORY
        );

        deployed =
            address(new ERC1967Proxy{ salt: salt }(implementation, initData));

        require(deployed == predicted, "create2: address mismatch");
    }
}
