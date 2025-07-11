import { ethers, upgrades } from "hardhat";
import "@openzeppelin/hardhat-upgrades";
import { expect } from "chai";
import "@nomicfoundation/hardhat-chai-matchers";
import { Signer } from "ethers";
import { VMahout } from "../typechain-types";

describe("VMahout", function () {
  let VMahout: any;
  let vMahout: VMahout;
  let owner: Signer;
  let admin: Signer;
  let minter: Signer;
  let upgrader: Signer;
  let user1: Signer;
  let user2: Signer;

  beforeEach(async function () {
    [owner, admin, minter, upgrader, user1, user2] = await ethers.getSigners();

    const VMahoutFactory = await ethers.getContractFactory("VMahout");
    vMahout = (await upgrades.deployProxy(
      VMahoutFactory,
      [
        await admin.getAddress(),
        await minter.getAddress(),
        await upgrader.getAddress(),
      ],
      { initializer: "initialize" },
    )) as unknown as VMahout;
    await vMahout.waitForDeployment();
  });

  describe("Initialization", function () {
    it("should initialize with the correct name and symbol", async function () {
      expect(await vMahout.name()).to.equal("vMahout");
      expect(await vMahout.symbol()).to.equal("VMHT");
    });

    it("should set the correct admin, minter, and upgrader roles", async function () {
      const DEFAULT_ADMIN_ROLE = await vMahout.DEFAULT_ADMIN_ROLE();
      const MINTER_ROLE = await vMahout.MINTER_ROLE();
      const UPGRADER_ROLE = await vMahout.UPGRADER_ROLE();

      expect(
        await vMahout.hasRole(DEFAULT_ADMIN_ROLE, await admin.getAddress()),
      ).to.be.true;
      expect(await vMahout.hasRole(MINTER_ROLE, await minter.getAddress())).to
        .be.true;
      expect(await vMahout.hasRole(UPGRADER_ROLE, await upgrader.getAddress()))
        .to.be.true;
    });
  });

  describe("Token Properties", function () {
    it("should prevent transfers", async function () {
      await expect(
        vMahout.connect(user1).transfer(await user2.getAddress(), 100),
      ).to.be.revertedWithCustomError(vMahout, "VMahout__TransferNotAllowed");
    });

    it("should prevent transferFrom", async function () {
      await expect(
        vMahout
          .connect(user1)
          .transferFrom(
            await owner.getAddress(),
            await user2.getAddress(),
            100,
          ),
      ).to.be.revertedWithCustomError(vMahout, "VMahout__TransferNotAllowed");
    });

    it("should prevent approvals", async function () {
      await expect(
        vMahout.connect(user1).approve(await user2.getAddress(), 100),
      ).to.be.revertedWithCustomError(vMahout, "VMahout__TransferNotAllowed");
    });

    it("should be upgradeable", async function () {
      const VMahoutV2Factory = await ethers.getContractFactory("VMahout"); // Using same for test simplicity
      const vMahoutV2 = await upgrades.upgradeProxy(
        await vMahout.getAddress(),
        VMahoutV2Factory.connect(upgrader),
      );
      await vMahoutV2.waitForDeployment();
      expect(await vMahoutV2.getAddress()).to.equal(await vMahout.getAddress());
    });
  });

  describe("Minting Logic", function () {
    it("should allow minter to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      await vMahout.connect(minter).mint(await user1.getAddress(), amount);
      expect(await vMahout.balanceOf(await user1.getAddress())).to.equal(
        amount,
      );
      expect(await vMahout.totalSupply()).to.equal(amount);
    });

    it("should not allow non-minter to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      const MINTER_ROLE = await vMahout.MINTER_ROLE();
      const user1Address = await user1.getAddress();
      await expect(vMahout.connect(user1).mint(user1Address, amount))
        .to.be.revertedWithCustomError(
          vMahout,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(user1Address, MINTER_ROLE);
    });

    it("should mint correct amount of tokens", async function () {
      const firstMintAmount = ethers.parseEther("500");
      await vMahout
        .connect(minter)
        .mint(await user1.getAddress(), firstMintAmount);
      expect(await vMahout.balanceOf(await user1.getAddress())).to.equal(
        firstMintAmount,
      );

      const secondMintAmount = ethers.parseEther("300");

      await vMahout
        .connect(minter)
        .mint(await user2.getAddress(), secondMintAmount);
      expect(await vMahout.balanceOf(await user2.getAddress())).to.equal(
        secondMintAmount,
      );

      const totalMinted = BigInt(firstMintAmount) + BigInt(secondMintAmount);
      expect(await vMahout.totalSupply()).to.equal(totalMinted);
    });
  });
});
