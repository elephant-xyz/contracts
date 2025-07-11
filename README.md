# vMahout Smart Contracts

This repository contains the smart contracts for the vMahout ecosystem, including the vMahout governance token and PropertyDataConsensus system.

## Smart Contracts

| Contract | Address | Network | Description |
|----------|---------|---------|-------------|
| vMahout | [0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18](https://polygonscan.com/address/0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18) | Polygon Mainnet | Non-transferable ERC-20 governance token with minting capabilities |
| PropertyDataConsensus | [0x525E59e4DE2B51f52B9e30745a513E407652AB7c](https://polygonscan.com/address/0x525E59e4DE2B51f52B9e30745a513E407652AB7c) | Polygon Mainnet | Permissionless consensus system for property data validation |

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
  - Configurable consensus thresholds
  - Automatic vMahout rewards for consensus participants
  - Batch data submission support
  - Comprehensive consensus history tracking
  - Upgradeable via UUPS proxy pattern

## Integration

The PropertyDataConsensus contract integrates with the vMahout token to automatically mint rewards (0.016 vMahout tokens) to oracles when they participate in successful consensus rounds.

## Development

For development setup, testing, and deployment instructions, please see [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

This project is licensed under the MIT License.