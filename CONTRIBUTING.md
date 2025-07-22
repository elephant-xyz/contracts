# Contributing to vMahout Smart Contracts

This document provides development setup instructions and guidelines for contributing to the vMahout smart contracts.

## Prerequisites

1. [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
2. [Just](https://github.com/casey/just#installation) command runner
3. Git

## Development Setup

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd vMahout
just install
```

This installs Foundry dependencies including OpenZeppelin contracts and forge-std.

### 2. Environment Variables

Create a `.env` file in the root directory for deployment to public networks:

```dotenv
# RPC endpoints
AMOY_RPC_URL="https://..."
POLYGON_MAINNET_RPC_URL="https://..."

# API Keys
POLYGONSCAN_API_KEY="..."

# AWS KMS (for production deployments)
AWS_KMS_KEY_ID="..."
AWS_ROLE_TO_ASSUME="..."
```

When the RPC variables are undefined, deployment commands will fail gracefully, so local development works with no extra configuration.

## Testing

### Run All Tests

```bash
just test
```

This compiles the contracts and executes all Foundry tests on an in-memory blockchain.

### Run Specific Test Files

```bash
# PropertyDataConsensus tests
forge test --match-contract PropertyDataConsensusTest

# VMahout token tests  
forge test --match-contract VMahoutTest

# Run tests with verbose output
forge test -vvv
```

All tests must pass before submitting a pull request.

## Local Development

### Start Local Blockchain

```bash
# In one terminal, start a local Anvil node
anvil
```

### Deploy Contracts Locally

```bash
# Deploy all contracts to local network
just deploy localhost

# Deploy to Amoy testnet
just deploy amoy
```

The deployment script will print the deployed proxy addresses for interaction.

## Network Deployment

### Deploy to Polygon Mainnet

```bash
# Deploy to Polygon mainnet (requires AWS KMS setup)
just deploy polygon
```

**Deployment behavior:**
- Deploys UUPS proxies for both contracts
- The deployer address becomes defaultAdmin & upgrader
- Verifies both implementation and proxy on Polygonscan automatically
- Uses AWS KMS for secure key management in production

### Upgrade Existing Contracts

```bash
# Upgrade VMahout on Polygon
just upgrade-vmahout polygon

# Upgrade PropertyDataConsensus on Polygon  
just upgrade-consensus polygon

# Upgrade locally for testing
just upgrade-vmahout-local
just upgrade-consensus-local
```

The upgrade commands:
- Build reference contracts for upgrade validation
- Perform safety checks using OpenZeppelin Upgrades
- Execute the upgrade with proper verification
- Use AWS KMS for production deployments

## Useful Commands

```bash
# List all available commands
just

# Clean build artifacts
just clean

# Build contracts
just build

# Format code
just format

# Run linter
just lint

# Run all checks (format, lint, build, test)
just check

# Grant LEXICON_ORACLE_MANAGER_ROLE
just grant-roles polygon
```

## Contract Architecture

### vMahout Token (VMahout.sol)
- **Pattern**: UUPS Upgradeable Proxy
- **Base Contracts**: ERC20Upgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Can upgrade contract and manage roles
  - `MINTER_ROLE`: Can mint tokens to addresses
  - `UPGRADER_ROLE`: Can authorize upgrades
- **Special Features**: Non-transferable token (transfers, approvals blocked)

### PropertyDataConsensus (PropertyDataConsensus.sol)
- **Pattern**: UUPS Upgradeable Proxy
- **Base Contracts**: AccessControlUpgradeable, Initializable
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Can upgrade contract, update consensus parameters, and set vMahout address
  - `LEXICON_ORACLE_MANAGER_ROLE`: Can configure consensus requirements for data groups
- **Integration**: Automatically mints vMahout tokens to oracles on consensus

## Testing Guidelines

1. **Write comprehensive tests** for all new functionality using Foundry's testing framework
2. **Test edge cases** and error conditions with proper revert testing
3. **Use realistic test data** (proper hash values, addresses, etc.)
4. **Test contract interactions** between vMahout and PropertyDataConsensus
5. **Verify events** are emitted correctly using `vm.expectEmit`
6. **Test access control** for all restricted functions
7. **Use fuzzing** for testing with random inputs where appropriate

## Code Style

- Follow existing code patterns and conventions
- Use descriptive variable and function names
- Add comprehensive NatSpec documentation
- Use OpenZeppelin's security patterns and latest versions
- Never expose or log secrets/private keys
- Follow Foundry best practices for development and testing
- Use `forge fmt` for consistent code formatting

## Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Ensure all checks pass: `just check`
5. Submit a pull request with a clear description

## Security

- Always follow security best practices
- Use OpenZeppelin's audited contracts where possible (keep dependencies updated)
- Be cautious with upgradeable contracts - use OpenZeppelin Upgrades validation
- Test thoroughly before deploying to mainnet
- Consider getting security audits for major changes
- Regularly update dependencies to patch security vulnerabilities
- Use AWS KMS for production key management

## CI/CD

The project uses GitHub Actions for continuous integration:

- **Pull Requests**: Run `just check` and perform dry-run upgrades
- **Main Branch**: Automatically deploy upgrades to Polygon mainnet
- **Manual Workflows**: Grant roles and perform specific operations

All CI operations use justfile commands for consistency between local development and CI environments.
