import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";

/**
 * Hardhat task: deploy-vmahout
 * Deploys the VMahout ERC20Votes token behind a UUPS proxy.
 *   --minter <address>   Address that will receive the MINTER_ROLE.
 *   --verify             (optional) Verify the implementation on Etherscan.
 */
// eslint-disable-next-line @typescript-eslint/no-misused-promises
export default task("deploy-vmahout", "Deploy VMahout token")
  .addParam(
    "minter",
    "Address that will receive MINTER_ROLE",
    undefined,
    types.string,
  )
  .addOptionalParam(
    "verify",
    "Verify implementation on Etherscan",
    false,
    types.boolean,
  )
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { minter, verify } = taskArgs;

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

    // Optionally verify the implementation contract
    if (verify) {
      const implAddress =
        await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
      console.log(`Verifying implementation at ${implAddress}…`);
      await hre.run("verify:verify", { address: implAddress });
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

    // Ensure the proxy is registered in the upgrades manifest when running on a fresh environment.
    await hre.upgrades.forceImport(proxy, VMahoutFactory, { kind: "uups" });

    const upgraded = await hre.upgrades.upgradeProxy(proxy, VMahoutFactory);
    await upgraded.waitForDeployment();

    console.log(
      `Upgrade complete. Proxy still at: ${await upgraded.getAddress()}`,
    );

    return upgraded.getAddress();
  });
