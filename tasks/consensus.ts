import { task } from "hardhat/config";

// Simple sleep helper
const sleep = (ms: number) => new Promise((res) => setTimeout(res, ms));

// Helper to verify a contract and swallow errors (e.g. already verified)
async function verifySafe(
  hre: any,
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

task("upgradeConsensus", "Upgrade PropertyDataConsensus contract")
  .addParam("proxy", "The proxy address to upgrade")
  .addOptionalParam(
    "approveafterimport",
    "Address to approve if forceImport is used",
  )
  .addOptionalParam("vmahout", "Address of vMahout token to set after upgrade")
  .setAction(async (taskArgs, hre) => {
    const { proxy, vmahout } = taskArgs;
    const [deployer] = await hre.ethers.getSigners();

    console.log(`Upgrading PropertyDataConsensus proxy at ${proxy}…`);
    console.log(`  Upgrader (tx sender): ${deployer.address}`);

    const ConsensusFactory = await hre.ethers.getContractFactory(
      "PropertyDataConsensus",
    );

    await hre.upgrades.forceImport(proxy, ConsensusFactory, { kind: "uups" });

    const upgraded = await hre.upgrades.upgradeProxy(proxy, ConsensusFactory);
    await upgraded.waitForDeployment();

    console.log(
      `Upgrade complete. Proxy still at: ${await upgraded.getAddress()}`,
    );

    // Set vMahout address if provided
    if (vmahout) {
      console.log(`Setting vMahout address to ${vmahout}…`);
      const setVMahoutTx = await upgraded.setVMahout(vmahout);
      await setVMahoutTx.wait();
      console.log(`vMahout address set to ${vmahout}`);
    }

    // Verify new implementation on real networks
    if (!["hardhat", "localhost"].includes(hre.network.name)) {
      console.log(
        "Waiting 90 seconds before verification so explorer can index the upgrade…",
      );
      await sleep(90_000);

      const implAddress =
        await hre.upgrades.erc1967.getImplementationAddress(proxy);
      console.log(`Verifying new implementation at ${implAddress}…`);
      await verifySafe(hre, implAddress);

      // Wait a bit to avoid rate limiting
      console.log("Waiting 5 seconds to avoid rate limiting…");
      await sleep(5_000);

      // Attempt proxy verification (will be skipped if already verified)
      console.log(`Verifying proxy at ${proxy}…`);
      await verifySafe(hre, proxy, {
        contract:
          "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
      });
    }
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
