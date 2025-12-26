# Elephant Protocol Smart Contracts

This repository contains the smart contracts for the vMahout ecosystem, including the vMahout governance token and PropertyDataConsensus system.

## Smart Contracts

| Contract              | Address                                                                                                                  | Network         | Description                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------- | ------------------------------------------------------------------ |
| vMahout               | [0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18](https://polygonscan.com/address/0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18) | Polygon Mainnet | Non-transferable ERC-20 governance token with minting capabilities |
| PropertyDataConsensus | [0x525E59e4DE2B51f52B9e30745a513E407652AB7c](https://polygonscan.com/address/0x525E59e4DE2B51f52B9e30745a513E407652AB7c) | Polygon Mainnet | Permissionless consensus system for property data validation       |
| Mahout                | [0xF7B26dEDDc5EfF1F0253bC0452244822951c1C97](https://polygonscan.com/address/0xF7B26dEDDc5EfF1F0253bC0452244822951c1C97) | Polygon Mainnet | ERC-20 token used by protocol                                      |

## Contract Overview

### vMahout Token (VMahout.sol)

- **Purpose**: Non-transferable governance token that rewards oracles for participating in consensus
- **Features**:
  - ERC-20 compliant with voting capabilities
  - Non-transferable (transfers are disabled)
  - Mintable by authorized contracts
  - Upgradeable via UUPS proxy pattern
  - Role-based access control

### PropertyDataConsensus (PropertyDataConsensus.sol)

- **Purpose**: Decentralized consensus mechanism for validating property data
- **Features**:
  - Permissionless oracle participation
  - Configurable consensus thresholds (global and per-data-group)
  - Automatic vMahout rewards for consensus participants
  - Batch data submission support
  - Comprehensive consensus history tracking
  - Upgradeable via UUPS proxy pattern

### Mahout Token (Mahout.sol)

- **Purpose**: ERC-20 token used by the protocol with controlled supply and minting
- **Features**:
  - Standard ERC-20 functionality with permit extension
  - Maximum supply capped at 150 million tokens
  - Initial mint of 50 million tokens to designated recipient
  - Role-based minting controlled by MINTER_ROLE
  - Upgradeable via UUPS proxy pattern
  - Dual initialization support (standard and reinitializer for v2 upgrades)


## Development

For development setup, testing, and deployment instructions, please see [CONTRIBUTING.md](./CONTRIBUTING.md).
