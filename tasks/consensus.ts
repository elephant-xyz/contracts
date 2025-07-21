import { task } from "hardhat/config";

task("upgradeConsensus", "Upgrade PropertyDataConsensus contract")
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

task(
  "grantLexiconOracleManager",
  "Grant LEXICON_ORACLE_MANAGER_ROLE to an address",
)
  .addParam("proxy", "The PropertyDataConsensus proxy address")
  .addParam("recipient", "The address to grant the role to")
  .setAction(async (taskArgs, hre) => {
    const { proxy, recipient } = taskArgs;
    const [deployer] = await hre.ethers.getSigners();

    console.log(
      `Granting LEXICON_ORACLE_MANAGER_ROLE on PropertyDataConsensus at ${proxy}…`,
    );
    console.log(`  Granter (tx sender): ${deployer.address}`);
    console.log(`  Recipient: ${recipient}`);

    const PropertyDataConsensus = await hre.ethers.getContractFactory(
      "PropertyDataConsensus",
    );
    const consensus = PropertyDataConsensus.attach(proxy);

    // Get the role hash
    const LEXICON_ORACLE_MANAGER_ROLE =
      await consensus.LEXICON_ORACLE_MANAGER_ROLE();
    console.log(`  Role hash: ${LEXICON_ORACLE_MANAGER_ROLE}`);

    // Grant the role
    const tx = await consensus.grantRole(
      LEXICON_ORACLE_MANAGER_ROLE,
      recipient,
    );
    console.log(`  Transaction hash: ${tx.hash}`);

    await tx.wait();
    console.log(`  ✅ Role granted successfully!`);

    // Verify the role was granted
    const hasRole = await consensus.hasRole(
      LEXICON_ORACLE_MANAGER_ROLE,
      recipient,
    );
    console.log(
      `  Verification: ${recipient} has LEXICON_ORACLE_MANAGER_ROLE: ${hasRole}`,
    );
  });
