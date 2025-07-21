import { HardhatUserConfig } from "hardhat/config";
import { ethers } from "ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@rumblefishdev/hardhat-kms-signer";
import "./tasks/vmahout";
import "./tasks/consensus";

const DEFAULT_GAS_LIMIT = process.env.GAS_LIMIT
  ? parseInt(process.env.GAS_LIMIT)
  : 300000000000000;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
  },
  sourcify: {
    enabled: true,
  },
  networks: (() => {
    const nets: Record<string, any> = {
      // For local development
      hardhat: {
        chainId: 31337,
      },
      // For local node
      localhost: {
        url: "http://127.0.0.1:8545",
      },
    };

    if (process.env.AMOY_RPC_URL) {
      nets["amoy"] = {
        url: process.env.AMOY_RPC_URL,
        gas: DEFAULT_GAS_LIMIT,
        kmsKeyId: process.env.KMS_KEY_ID,
        gasPrice: 35000000000,
        minMaxFeePerGas: 1600000000,
        minMaxPriorityFeePerGas: Number(ethers.parseUnits("25", "gwei")),
      };
    }

    if (process.env.POLYGON_MAINNET_RPC_URL) {
      nets["polygon"] = {
        url: process.env.POLYGON_MAINNET_RPC_URL,
        kmsKeyId: process.env.KMS_KEY_ID,
        gas: "auto",
        gasPrice: 35000000000,
        minMaxFeePerGas: 1600000000,
        minMaxPriorityFeePerGas: Number(ethers.parseUnits("25", "gwei")),
        loggingEnabled: true,
        throwOnCallFailures: true,
        throwOnTransactionFailures: true,
      };
    }

    return nets;
  })(),
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY || ETHERSCAN_API_KEY,
  },
};

export default config;
