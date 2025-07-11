import { ethers, upgrades } from "hardhat";
import "@openzeppelin/hardhat-upgrades";
import { expect } from "chai";
import type {
  ContractFactory,
  Signer as EthersSigner,
  AbiCoder,
  BytesLike,
} from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  PropertyDataConsensus,
  IPropertyDataConsensus,
} from "../typechain-types";
import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("PropertyDataConsensus", function () {
  let propertyDataConsensus: PropertyDataConsensus;
  let admin: SignerWithAddress;
  let unprivilegedUser: SignerWithAddress;
  let oracle1: SignerWithAddress;
  let oracle2: SignerWithAddress;
  let oracle3: SignerWithAddress;

  let adminAddress: string;
  let unprivilegedUserAddress: string;
  let oracle1Address: string;
  let oracle2Address: string;
  let oracle3Address: string;

  let DEFAULT_ADMIN_ROLE: string;
  let PropertyDataConsensusFactory: ContractFactory;

  // Real SHA-256 hashes from realistic data content
  const propertyHash1 = ethers.sha256(
    ethers.toUtf8Bytes("property-123-main-data"),
  );
  const dataGroupHash1 = ethers.sha256(
    ethers.toUtf8Bytes("location-coordinates-group"),
  );
  const dataHash1 = ethers.sha256(
    ethers.toUtf8Bytes("latitude: 40.7128, longitude: -74.0060"),
  );
  const dataHash2 = ethers.sha256(
    ethers.toUtf8Bytes("latitude: 40.7589, longitude: -73.9851"),
  );

  async function deployPropertyDataConsensusFixture() {
    const [
      adminSigner,
      unprivilegedUserSigner,
      oracle1Signer,
      oracle2Signer,
      oracle3Signer,
    ] = await ethers.getSigners();

    const factory = await ethers.getContractFactory(
      "PropertyDataConsensus",
      adminSigner as unknown as EthersSigner,
    );

    const deployedConsensus = (await upgrades.deployProxy(
      factory,
      [3, await adminSigner.getAddress()],
      { initializer: "initialize(uint256,address)", kind: "uups" },
    )) as unknown as PropertyDataConsensus;

    await deployedConsensus.waitForDeployment();

    const adminRole = await deployedConsensus.DEFAULT_ADMIN_ROLE();

    return {
      deployedConsensus,
      adminSigner,
      unprivilegedUserSigner,
      oracle1Signer,
      oracle2Signer,
      oracle3Signer,
      adminRole,
      factory,
    };
  }

  beforeEach(async function () {
    const {
      deployedConsensus,
      adminSigner,
      unprivilegedUserSigner,
      oracle1Signer,
      oracle2Signer,
      oracle3Signer,
      adminRole,
      factory,
    } = await loadFixture(deployPropertyDataConsensusFixture);

    propertyDataConsensus = deployedConsensus;
    admin = adminSigner;
    unprivilegedUser = unprivilegedUserSigner;
    oracle1 = oracle1Signer;
    oracle2 = oracle2Signer;
    oracle3 = oracle3Signer;

    adminAddress = await admin.getAddress();
    unprivilegedUserAddress = await unprivilegedUser.getAddress();
    oracle1Address = await oracle1.getAddress();
    oracle2Address = await oracle2.getAddress();
    oracle3Address = await oracle3.getAddress();

    DEFAULT_ADMIN_ROLE = adminRole;
    PropertyDataConsensusFactory = factory;
  });

  describe("Initialization", function () {
    it("Should set the deployer as the initial admin (DEFAULT_ADMIN_ROLE)", async function () {
      expect(
        await propertyDataConsensus.hasRole(DEFAULT_ADMIN_ROLE, adminAddress),
      ).to.be.true;
    });

    it("Should set the initial minimum consensus", async function () {
      expect(await propertyDataConsensus.minimumConsensus()).to.equal(3);
    });

    it("Should set minimum consensus to 3 if initialized with less than 3", async function () {
      const Factory = await ethers.getContractFactory(
        "PropertyDataConsensus",
        admin as unknown as EthersSigner,
      );
      const consensus = (await upgrades.deployProxy(
        Factory,
        [1, adminAddress],
        { initializer: "initialize(uint256,address)", kind: "uups" },
      )) as PropertyDataConsensus;
      await consensus.waitForDeployment();

      expect(await consensus.minimumConsensus()).to.equal(3);
    });

    it("Should not allow re-initialization", async function () {
      await expect(
        propertyDataConsensus.initialize(3, unprivilegedUserAddress),
      ).to.be.revertedWithCustomError(
        propertyDataConsensus,
        "InvalidInitialization",
      );
    });
  });

  describe("updateMinimumConsensus", function () {
    it("Should allow admin to update minimum consensus", async function () {
      await expect(
        propertyDataConsensus.connect(admin).updateMinimumConsensus(4),
      )
        .to.emit(propertyDataConsensus, "MinimumConsensusUpdated")
        .withArgs(3, 4);
      expect(await propertyDataConsensus.minimumConsensus()).to.equal(4);
    });

    it("Should prevent account without DEFAULT_ADMIN_ROLE from updating", async function () {
      await expect(
        propertyDataConsensus
          .connect(unprivilegedUser)
          .updateMinimumConsensus(5),
      )
        .to.be.revertedWithCustomError(
          PropertyDataConsensusFactory,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(unprivilegedUserAddress, DEFAULT_ADMIN_ROLE);
    });

    it("Should revert if new minimum consensus is less than 3", async function () {
      await expect(
        propertyDataConsensus.connect(admin).updateMinimumConsensus(2),
      ).to.be.revertedWithCustomError(
        PropertyDataConsensusFactory,
        "InvalidMinimumConsensus",
      );
    });
  });

  describe("Consensus Logic", function () {
    it("Should reach consensus when minimum submissions are met", async function () {
      await propertyDataConsensus
        .connect(oracle1)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      await propertyDataConsensus
        .connect(oracle2)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);

      await expect(
        propertyDataConsensus
          .connect(oracle3)
          .submitData(propertyHash1, dataGroupHash1, dataHash1),
      )
        .to.emit(propertyDataConsensus, "ConsensusReached")
        .withArgs(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
          (emittedOracles: string[]) => {
            expect([...emittedOracles]).to.have.members([
              oracle1Address,
              oracle2Address,
              oracle3Address,
            ]);
            return true;
          },
        );

      expect(
        await propertyDataConsensus.getCurrentFieldDataHash(
          propertyHash1,
          dataGroupHash1,
        ),
      ).to.equal(dataHash1);
      const history = await propertyDataConsensus.getConsensusHistory(
        propertyHash1,
        dataGroupHash1,
      );
      expect(history.length).to.equal(1);
      expect(history[0].dataHash).to.equal(dataHash1);
      expect([...history[0].oracles]).to.have.members([
        oracle1Address,
        oracle2Address,
        oracle3Address,
      ]);
    });

    it("Should update consensus when a new dataHash reaches minimum submissions", async function () {
      await propertyDataConsensus
        .connect(oracle1)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      await propertyDataConsensus
        .connect(oracle2)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      await propertyDataConsensus
        .connect(oracle3)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      expect(
        await propertyDataConsensus.getCurrentFieldDataHash(
          propertyHash1,
          dataGroupHash1,
        ),
      ).to.equal(dataHash1);

      await propertyDataConsensus
        .connect(oracle1)
        .submitData(propertyHash1, dataGroupHash1, dataHash2);
      await propertyDataConsensus
        .connect(oracle2)
        .submitData(propertyHash1, dataGroupHash1, dataHash2);
      await expect(
        propertyDataConsensus
          .connect(oracle3)
          .submitData(propertyHash1, dataGroupHash1, dataHash2),
      )
        .to.emit(propertyDataConsensus, "ConsensusUpdated")
        .withArgs(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
          dataHash2,
          (emittedOracles: string[]) => {
            expect([...emittedOracles]).to.have.members([
              oracle1Address,
              oracle2Address,
              oracle3Address,
            ]);
            return true;
          },
        );

      expect(
        await propertyDataConsensus.getCurrentFieldDataHash(
          propertyHash1,
          dataGroupHash1,
        ),
      ).to.equal(dataHash2);
      const history = await propertyDataConsensus.getConsensusHistory(
        propertyHash1,
        dataGroupHash1,
      );
      expect(history.length).to.equal(2);
      expect(history[1].dataHash).to.equal(dataHash2);
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      await propertyDataConsensus
        .connect(oracle1)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      await propertyDataConsensus
        .connect(oracle2)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
      await propertyDataConsensus
        .connect(oracle3)
        .submitData(propertyHash1, dataGroupHash1, dataHash1);
    });

    it("getCurrentFieldDataHash: Should return current consensus hash or zero if none", async function () {
      expect(
        await propertyDataConsensus.getCurrentFieldDataHash(
          propertyHash1,
          dataGroupHash1,
        ),
      ).to.equal(dataHash1);
      const propertyHash2_local = ethers.sha256(
        ethers.toUtf8Bytes("property-789-local-test"),
      );
      expect(
        await propertyDataConsensus.getCurrentFieldDataHash(
          propertyHash2_local,
          dataGroupHash1,
        ),
      ).to.equal(ethers.ZeroHash);
    });

    it("getSubmitterCountForDataHash: Should return correct count", async function () {
      expect(
        await propertyDataConsensus.getSubmitterCountForDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
        ),
      ).to.equal(3);
      expect(
        await propertyDataConsensus.getSubmitterCountForDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash2,
        ),
      ).to.equal(0);
    });

    it("getConsensusHistory: Should return history", async function () {
      const history = await propertyDataConsensus.getConsensusHistory(
        propertyHash1,
        dataGroupHash1,
      );
      expect(history.length).to.equal(1);
      expect(history[0].dataHash).to.equal(dataHash1);
    });

    it("getParticipantsForConsensusDataHash: Should return participants for a specific consensus hash", async function () {
      const participants =
        await propertyDataConsensus.getParticipantsForConsensusDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
        );
      expect([...participants]).to.have.members([
        oracle1Address,
        oracle2Address,
        oracle3Address,
      ]);
    });

    it("getParticipantsForConsensusDataHash: Should revert if dataHash never reached consensus", async function () {
      await expect(
        propertyDataConsensus.getParticipantsForConsensusDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash2,
        ),
      ).to.be.revertedWithCustomError(
        propertyDataConsensus,
        "NoConsensusReachedForDataHash",
      );
    });

    it("getCurrentConsensusParticipants: Should return participants for current consensus", async function () {
      const participants =
        await propertyDataConsensus.getCurrentConsensusParticipants(
          propertyHash1,
          dataGroupHash1,
        );
      expect([...participants]).to.have.members([
        oracle1Address,
        oracle2Address,
        oracle3Address,
      ]);
    });

    it("getCurrentConsensusParticipants: Should return empty array if no consensus", async function () {
      const propertyHash2_local = ethers.sha256(
        ethers.toUtf8Bytes("property-999-current-test"),
      );
      const participants =
        await propertyDataConsensus.getCurrentConsensusParticipants(
          propertyHash2_local,
          dataGroupHash1,
        );
      expect(participants.length).to.equal(0);
    });

    it("hasUserSubmittedDataHash: Should return true if user submitted, false otherwise", async function () {
      expect(
        await propertyDataConsensus.hasUserSubmittedDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
          oracle1Address,
        ),
      ).to.be.true;
      expect(
        await propertyDataConsensus.hasUserSubmittedDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash2,
          oracle1Address,
        ),
      ).to.be.false;
      expect(
        await propertyDataConsensus.hasUserSubmittedDataHash(
          propertyHash1,
          dataGroupHash1,
          dataHash1,
          unprivilegedUserAddress,
        ),
      ).to.be.false;
    });
  });

  describe("Upgradeability", function () {
    it("Should allow the admin (DEFAULT_ADMIN_ROLE) to upgrade the contract", async function () {
      const V2Factory = await ethers.getContractFactory(
        "PropertyDataConsensus",
        admin as unknown as EthersSigner,
      );
      const upgradedConsensus = (await upgrades.upgradeProxy(
        await propertyDataConsensus.getAddress(),
        V2Factory,
      )) as PropertyDataConsensus;
      await upgradedConsensus.waitForDeployment();

      expect(await upgradedConsensus.getAddress()).to.equal(
        await propertyDataConsensus.getAddress(),
      );
      await expect(
        upgradedConsensus
          .connect(admin as unknown as EthersSigner)
          .updateMinimumConsensus(4),
      ).to.not.be.reverted;
      expect(await upgradedConsensus.minimumConsensus()).to.equal(4);
      expect(await upgradedConsensus.hasRole(DEFAULT_ADMIN_ROLE, adminAddress))
        .to.be.true;
    });

    it("Should not allow a non-admin to upgrade the contract", async function () {
      // Get a factory instance connected to the unprivilegedUser for the upgrade attempt
      const FactoryAsUnprivileged = PropertyDataConsensusFactory.connect(
        unprivilegedUser as unknown as EthersSigner,
      );

      await expect(
        upgrades.upgradeProxy(
          await propertyDataConsensus.getAddress(),
          FactoryAsUnprivileged,
        ),
      )
        .to.be.revertedWithCustomError(
          PropertyDataConsensusFactory,
          "AccessControlUnauthorizedAccount",
        )
        .withArgs(unprivilegedUserAddress, DEFAULT_ADMIN_ROLE);
    });
  });
});
