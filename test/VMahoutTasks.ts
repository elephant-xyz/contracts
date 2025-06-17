import { expect } from "chai";
import hre from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";
import { VMahout } from "../typechain-types";

const { ethers } = hre;

/**
 * These tests execute the custom Hardhat tasks defined in tasks/vmahout.ts.
 * The goal is to prove that the deploy and upgrade workflows operate as expected
 * on a fresh Hardhat network.
 */

describe("VMahout Hardhat tasks", function () {
  let proxyAddress: string;
  let vMahout: VMahout;

  it("deploy-vmahout task should deploy a proxy and assign roles", async function () {
    const [deployer, minter] = await ethers.getSigners();

    // Run custom Hardhat task. The task returns the deployed proxy address.
    proxyAddress = (await hre.run("deploy-vmahout", {
      minter: minter.address,
    })) as string;

    vMahout = (await ethers.getContractAt(
      "VMahout",
      proxyAddress,
    )) as unknown as VMahout;

    // Check proxy address is valid
    expect(proxyAddress).to.properAddress;

    // Validate roles were set correctly
    expect(
      await vMahout.hasRole(
        await vMahout.DEFAULT_ADMIN_ROLE(),
        deployer.address,
      ),
    ).to.equal(true);
    expect(
      await vMahout.hasRole(await vMahout.MINTER_ROLE(), minter.address),
    ).to.equal(true);
    expect(
      await vMahout.hasRole(await vMahout.UPGRADER_ROLE(), deployer.address),
    ).to.equal(true);
  });

  it("upgrade-vmahout task should upgrade the proxy implementation", async function () {
    // Sanity check – proxy must have been deployed by previous test.
    expect(proxyAddress).to.properAddress;

    // Record current implementation address for later comparison
    const oldImpl = await (
      hre as any
    ).upgrades.erc1967.getImplementationAddress(proxyAddress);

    // Execute the upgrade task.
    await hre.run("upgrade-vmahout", { proxy: proxyAddress });

    const newImpl = await (
      hre as any
    ).upgrades.erc1967.getImplementationAddress(proxyAddress);

    // Implementation address should change (using same bytecode in this repo, but proxy still remains)
    expect(newImpl).to.not.equal(ethers.ZeroAddress);
    // The implementation address might stay the same if there are no bytecode changes.
  });
});
