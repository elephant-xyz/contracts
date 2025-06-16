import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";

// Helper to verify a contract and swallow errors (e.g. already verified)
async function verifySafe(
  hre: HardhatRuntimeEnvironment,
  addr: string,
  extra: Record<string, any> = {},
) {
  try {
    await hre.run("verify:verify", { address: addr, ...extra });
  } catch (err: any) {
    console.warn(
      `Verification skipped/failed for ${addr}: ${err.message ?? err}`,
    );
  }
}

/**
 * Hardhat task: deploy-vmahout
 * Deploys the VMahout ERC20Votes token behind a UUPS proxy.
 *   --minter <address>   Address that will receive the MINTER_ROLE.
 */
// eslint-disable-next-line @typescript-eslint/no-misused-promises
export default task("deploy-vmahout", "Deploy VMahout token")
  .addParam(
    "minter",
    "Address that will receive MINTER_ROLE",
    undefined,
    types.string,
  )
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { minter } = taskArgs;

    if (!ethers.isAddress(minter)) {
      throw new Error(`Invalid minter address: ${minter}`);
    }

    const [deployer] = await hre.ethers.getSigners();

    console.log(`Deploying VMahout…`);
    console.log(`  Deployer (admin & upgrader): ${deployer.address}`);
    console.log(`  Minter:                      ${minter}`);

    const VMahoutFactory = await hre.ethers.getContractFactory("VMahout");

    const proxy = await hre.upgrades.deployProxy(
      VMahoutFactory,
      [deployer.address, minter, deployer.address],
      {
        initializer: "initialize",
        kind: "uups",
      },
    );

    await proxy.waitForDeployment();

    const proxyAddress = await proxy.getAddress();
    console.log(`VMahout proxy deployed at: ${proxyAddress}`);

    // Verify implementation & proxy when running on a real network
    if (!["hardhat", "localhost"].includes(hre.network.name)) {
      const implAddress =
        await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
      console.log(`Verifying implementation at ${implAddress}…`);
      await verifySafe(hre, implAddress);

      const initData = VMahoutFactory.interface.encodeFunctionData(
        "initialize",
        [deployer.address, minter, deployer.address],
      );
      console.log(`Verifying proxy at ${proxyAddress}…`);
      await verifySafe(hre, proxyAddress, {
        contract:
          "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
        constructorArguments: [implAddress, initData],
      });
    }

    return proxyAddress;
  });

/**
 * Hardhat task: upgrade-vmahout
 * Upgrades an existing VMahout proxy to the latest implementation.
 *   --proxy <address>   Address of the existing proxy.
 */
// eslint-disable-next-line @typescript-eslint/no-misused-promises
export const upgradeTask = task("upgrade-vmahout", "Upgrade VMahout token")
  .addParam("proxy", "Existing proxy address", undefined, types.string)
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { proxy } = taskArgs;

    if (!ethers.isAddress(proxy)) {
      throw new Error(`Invalid proxy address: ${proxy}`);
    }

    const [deployer] = await hre.ethers.getSigners();

    console.log(`Upgrading VMahout proxy at ${proxy}…`);
    console.log(`  Upgrader (tx sender): ${deployer.address}`);

    const VMahoutFactory = await hre.ethers.getContractFactory("VMahout");

    await hre.upgrades.forceImport(proxy, VMahoutFactory, { kind: "uups" });

    const upgraded = await hre.upgrades.upgradeProxy(proxy, VMahoutFactory);
    await upgraded.waitForDeployment();

    console.log(
      `Upgrade complete. Proxy still at: ${await upgraded.getAddress()}`,
    );

    // Verify new implementation & (re-)verify proxy on real networks
    if (!["hardhat", "localhost"].includes(hre.network.name)) {
      const implAddress =
        await hre.upgrades.erc1967.getImplementationAddress(proxy);
      console.log(`Verifying new implementation at ${implAddress}…`);
      await verifySafe(hre, implAddress);

      // Attempt proxy verification again (will be skipped if already verified)
      await verifySafe(hre, proxy, {
        contract:
          "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
      });
    }

    return upgraded.getAddress();
  });
