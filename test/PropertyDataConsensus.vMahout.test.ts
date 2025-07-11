import { expect } from "chai";
import "@openzeppelin/hardhat-upgrades";
import { ethers, upgrades } from "hardhat";
import { VMahout } from "../typechain-types";

describe("PropertyDataConsensus – vMahout integration", function () {
  async function deployFixture() {
    const [admin, oracle1, oracle2, oracle3, unprivileged] =
      await ethers.getSigners();

    // Deploy consensus proxy
    const ConsensusFactory = await ethers.getContractFactory(
      "PropertyDataConsensus",
    );
    const consensus = await upgrades.deployProxy(
      ConsensusFactory,
      [
        3, // minimumConsensus
        await admin.getAddress(), // initialAdmin
      ],
      {
        initializer: "initialize(uint256,address)",
        kind: "uups",
      },
    );
    await consensus.waitForDeployment();

    // Deploy actual vMahout contract
    const VMahoutFactory = await ethers.getContractFactory("VMahout");
    const vMahout = (await upgrades.deployProxy(
      VMahoutFactory,
      [
        await admin.getAddress(), // defaultAdmin
        await consensus.getAddress(), // minter (consensus contract)
        await admin.getAddress(), // upgrader
      ],
      {
        initializer: "initialize(address,address,address)",
        kind: "uups",
      },
    )) as VMahout;
    await vMahout.waitForDeployment();

    return {
      admin,
      oracle1,
      oracle2,
      oracle3,
      unprivileged,
      consensus,
      vMahout,
    };
  }

  const propertyHash1 = ethers.sha256(
    ethers.toUtf8Bytes("property-123-main-data"),
  );
  const dataGroupHash1 = ethers.sha256(
    ethers.toUtf8Bytes("location-coordinates-group"),
  );
  const dataHash1 = ethers.sha256(
    ethers.toUtf8Bytes("latitude: 40.7128, longitude: -74.0060"),
  );

  it("Only admin can set vMahout address", async function () {
    const { consensus, vMahout, unprivileged } = await deployFixture();

    await expect(
      (consensus as any)
        .connect(unprivileged)
        .setVMahout(await vMahout.getAddress()),
    ).to.be.reverted; // AccessControl should block non-admin
  });

  it("Setting vMahout address stores the value", async function () {
    const { consensus, vMahout, admin } = await deployFixture();

    await (consensus as any)
      .connect(admin)
      .setVMahout(await vMahout.getAddress());

    expect(await (consensus as any).vMahout()).to.equal(
      await vMahout.getAddress(),
    );
  });

  it("Consensus submission mints rewards via vMahout token", async function () {
    const { consensus, vMahout, admin, oracle1, oracle2, oracle3 } =
      await deployFixture();

    // Set vMahout address
    await (consensus as any)
      .connect(admin)
      .setVMahout(await vMahout.getAddress());

    // Initial balances should be zero
    expect(await vMahout.balanceOf(await oracle1.getAddress())).to.equal(0n);

    // Oracle submissions
    await consensus
      .connect(oracle1)
      .submitData(propertyHash1, dataGroupHash1, dataHash1);
    await consensus
      .connect(oracle2)
      .submitData(propertyHash1, dataGroupHash1, dataHash1);

    // Not enough for consensus yet => still zero
    expect(await vMahout.balanceOf(await oracle1.getAddress())).to.equal(0n);

    // Third submission reaches consensus and should trigger minting
    await consensus
      .connect(oracle3)
      .submitData(propertyHash1, dataGroupHash1, dataHash1);

    const reward = ethers.parseEther("0.016");
    expect(await vMahout.balanceOf(await oracle1.getAddress())).to.equal(
      reward,
    );
    expect(await vMahout.balanceOf(await oracle2.getAddress())).to.equal(
      reward,
    );
    expect(await vMahout.balanceOf(await oracle3.getAddress())).to.equal(
      reward,
    );
  });
});
