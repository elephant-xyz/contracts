# Contributing to vMahout Smart Contracts

This document provides development setup instructions and guidelines for contributing to the vMahout smart contracts.

## Prerequisites

1. Node.js >= 20 (LTS version recommended)
2. npm (comes with Node.js)
3. Git

## Development Setup

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd vMahout
npm install
```

This installs Hardhat (latest version), OpenZeppelin contracts, and all other dependencies.

### 2. Environment Variables

Create a `.env` file in the root directory for deployment to public networks:

```dotenv
# RPC endpoints
AMOY_RPC_URL="https://..."
POLYGON_MAINNET_RPC_URL="https://..."

# Keys / secrets
KMS_KEY_ID="..."           # only if you use @rumblefishdev/hardhat-kms-signer
ETHERSCAN_API_KEY="..."    # or POLYGONSCAN_API_KEY
```

When the RPC variables are undefined, Hardhat will ignore those networks, so local development works with no extra configuration.

## Testing

### Run All Tests

```bash
npm test
```

This compiles the contracts and executes all tests (including contract and task tests) on an in-memory blockchain.

### Run Specific Test Files

```bash
# PropertyDataConsensus tests
npx hardhat test test/PropertyDataConsensus.test.ts

# vMahout integration tests
npx hardhat test test/PropertyDataConsensus.vMahout.test.ts

# vMahout token tests
npx hardhat test test/VMahout.test.ts
```

All tests must pass before submitting a pull request.

## Local Development

### Start Local Blockchain

```bash
# In one terminal, start a local Hardhat node
npx hardhat node
```

### Deploy Contracts Locally

```bash
# Deploy vMahout (use one of the default accounts as minter)
# The deployer automatically becomes DEFAULT_ADMIN_ROLE & UPGRADER_ROLE
npx hardhat deploy-vmahout --minter 0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73 --network localhost

# Deploy PropertyDataConsensus
npx hardhat deploy-consensus --network localhost
```

The tasks will print the deployed proxy addresses for interaction.

## Network Deployment

### Deploy to Polygon Mainnet

```bash
# Assumes POLYGON_MAINNET_RPC_URL & POLYGONSCAN_API_KEY are set
npx hardhat deploy-vmahout \
  --minter 0x1234...dead \
  --network polygon
```

**Deployment behavior:**
- Deploys a UUPS proxy
- The deployer address becomes defaultAdmin & upgrader
- Verifies both implementation and proxy on Polygonscan automatically

### Upgrade Existing Contracts

```bash
# Upgrade vMahout on Polygon
npx hardhat upgrade-vmahout \
  --proxy 0xProxyAddressHere \
  --network polygon

# Upgrade and grant MINTER_ROLE to a new address
npx hardhat upgrade-vmahout \
  --proxy 0xProxyAddressHere \
  --minter 0x1234...dead \
  --network polygon

# Upgrade PropertyDataConsensus
npx hardhat upgrade-consensus \
  --proxy 0xProxyAddressHere \
  --network polygon
```

The upgrade tasks:
- Force-import the proxy into a fresh local manifest
- Perform the upgrade
- Re-verify the new implementation and proxy if necessary
- Grant MINTER_ROLE to the specified address (if provided)

## Useful Commands

```bash
# Clean build artifacts
npx hardhat clean

# Compile contracts only
npx hardhat compile

# List all available tasks
npx hardhat help

# Run specific tasks
npx hardhat deploy-vmahout --help
npx hardhat upgrade-vmahout --help
```

## Contract Architecture

### vMahout Token (VMahout.sol)
- **Pattern**: UUPS Upgradeable Proxy
- **Base Contracts**: ERC20, AccessControl, ERC20Permit, ERC20Votes
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Can upgrade contract and manage roles
  - `MINTER_ROLE`: Can mint tokens to addresses
  - `UPGRADER_ROLE`: Can authorize upgrades

### PropertyDataConsensus (PropertyDataConsensus.sol)
- **Pattern**: UUPS Upgradeable Proxy
- **Base Contracts**: AccessControl, Initializable
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Can upgrade contract, update consensus parameters, and set vMahout address
- **Integration**: Automatically mints vMahout tokens to oracles on consensus

## Testing Guidelines

1. **Write comprehensive tests** for all new functionality
2. **Test edge cases** and error conditions
3. **Use realistic test data** (proper hash values, addresses, etc.)
4. **Test contract interactions** between vMahout and PropertyDataConsensus
5. **Verify events** are emitted correctly
6. **Test access control** for all restricted functions

## Code Style

- Follow existing code patterns and conventions
- Use descriptive variable and function names
- Add comprehensive NatSpec documentation
- Use OpenZeppelin's security patterns and latest versions
- Never expose or log secrets/private keys
- Follow Hardhat best practices for development and testing

## Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure all tests pass: `npm test`
5. Submit a pull request with a clear description

## Security

- Always follow security best practices
- Use OpenZeppelin's audited contracts where possible (keep dependencies updated)
- Be cautious with upgradeable contracts
- Test thoroughly before deploying to mainnet
- Consider getting security audits for major changes
- Regularly update dependencies to patch security vulnerabilities