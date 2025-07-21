# vMahout Smart Contracts

This repository contains the smart contracts for the vMahout ecosystem, including the vMahout governance token and PropertyDataConsensus system.

## Smart Contracts

| Contract              | Address                                                                                                                  | Network         | Description                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------- | ------------------------------------------------------------------ |
| vMahout               | [0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18](https://polygonscan.com/address/0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18) | Polygon Mainnet | Non-transferable ERC-20 governance token with minting capabilities |
| PropertyDataConsensus | [0x525E59e4DE2B51f52B9e30745a513E407652AB7c](https://polygonscan.com/address/0x525E59e4DE2B51f52B9e30745a513E407652AB7c) | Polygon Mainnet | Permissionless consensus system for property data validation       |

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

#### Configurable Consensus Thresholds

The PropertyDataConsensus contract supports both global and per-data-group consensus thresholds:

- **Global Threshold**: Set during initialization or via `updateMinimumConsensus()` (requires DEFAULT_ADMIN_ROLE)
- **Per-Data-Group Threshold**: Can be set using `setConsensusRequired()` (requires LEXICON_ORACLE_MANAGER_ROLE)

The per-data-group threshold allows fine-grained control over consensus requirements for different types of data. For example:

- Critical property valuations might require 5 oracles
- Less critical metadata might only require 3 oracles

**Usage Example**:

```solidity
// Grant LEXICON_ORACLE_MANAGER_ROLE to an address
consensus.grantRole(LEXICON_ORACLE_MANAGER_ROLE, managerAddress);

// Set custom threshold for a specific data group (minimum 3)
consensus.setConsensusRequired(dataGroupHash, 5);
```

## Integration

The PropertyDataConsensus contract integrates with the vMahout token to automatically mint rewards (0.016 vMahout tokens) to oracles when they participate in successful consensus rounds.

## Role Management

### Granting LEXICON_ORACLE_MANAGER_ROLE

The LEXICON_ORACLE_MANAGER_ROLE can be granted through a GitHub Actions workflow:

1. Navigate to the Actions tab in the repository
2. Select "Grant Roles" workflow
3. Click "Run workflow"
4. Fill in the required parameters:
   - Network: polygon or amoy
   - Proxy address: PropertyDataConsensus contract address
   - Recipient: Address to receive the role

**Note**: This workflow can only be executed by organization administrators for security reasons.

## Development

For development setup, testing, and deployment instructions, please see [CONTRIBUTING.md](./CONTRIBUTING.md).
