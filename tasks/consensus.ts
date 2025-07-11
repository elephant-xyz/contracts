import { task } from "hardhat/config";

export default task(
  "upgradeConsensus",
  "Upgrade PropertyDataConsensus contract",
)
  .addParam("proxy", "The proxy address to upgrade")
  .addOptionalParam(
    "approveafterimport",
    "Address to approve if forceImport is used",
  )
  .addOptionalParam("vmahout", "Address of vMahout token to set after upgrade")
  .setAction(async (taskArgs, hre) => {
    const { proxy } = taskArgs;
    const [deployer] = await hre.ethers.getSigners();

    console.log(`Upgrading VMahout proxy at ${proxy}…`);
    console.log(`  Upgrader (tx sender): ${deployer.address}`);

    const ConsensusFactory = await hre.ethers.getContractFactory(
      "PropertyDataConsensus",
    );

    await hre.upgrades.forceImport(proxy, ConsensusFactory, { kind: "uups" });

    const upgraded = await hre.upgrades.upgradeProxy(proxy, ConsensusFactory);
    await upgraded.waitForDeployment();
  });
