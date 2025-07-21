# vMahout - Hybrid Hardhat/Foundry Project

This project uses a hybrid approach combining Hardhat and Foundry:

- **Hardhat**: Testing, coverage, TypeScript tests
- **Foundry**: Deployment, upgrades, gas optimization, script execution

## Project Structure

```
vMahout/
├── contracts/                    # Smart contracts (used by Hardhat)
├── src/                          # Symlinks to contracts (used by Foundry)
├── script/                       # Foundry deployment scripts
├── test/                         # Hardhat TypeScript tests
├── tasks/                        # Hardhat tasks (legacy, can be removed)
├── lib/                          # Foundry dependencies
├── node_modules/                 # Node.js dependencies
├── previous-builds/              # Reference builds for upgrade validation
├── hardhat.config.ts             # Hardhat configuration
├── foundry.toml                  # Foundry configuration
├── justfile                      # Build automation commands
└── package.json                  # NPM scripts and dependencies
```

## Prerequisites

1. Node.js v22+ (only for running Hardhat tests locally)
2. Foundry (install from https://getfoundry.sh/)
3. AWS CLI configured (for KMS deployments)
4. Just (install from https://just.systems/)

## Installation

```bash
# Install Node.js dependencies (only needed for Hardhat tests)
npm install

# Install Foundry dependencies (already done via git submodules)
forge install
```

## Dependency Management

This project uses Foundry's git submodule approach for dependencies:

- All smart contract dependencies are installed as git submodules in `lib/`
- No dependency on `node_modules` for contract compilation or deployment
- Node.js dependencies are only used for Hardhat testing

## Configuration

Copy `.env.example` to `.env` and fill in the required values:

```bash
cp .env.example .env
```

## Common Commands

### Compilation

```bash
# Compile both Hardhat and Foundry
npm run compile

# Clean build artifacts
npm run clean
```

### Testing

```bash
# Run Hardhat tests
npm test

# Run tests with coverage
npm run coverage
```

### Linting and Formatting

```bash
# Lint Solidity files
npm run lint

# Check formatting
npm run format:check

# Fix formatting
npm run format

# Type check TypeScript files
npm run typecheck
```

### Deployment and Upgrades

#### Upgrade Validation

This project automatically validates storage layout compatibility during upgrades:

- **Feature branches**: Uses `main` branch as reference
- **Main branch**: Uses previous commit as reference

The reference build is automatically created before upgrades to ensure storage layout compatibility.

#### Deploy with Just + Foundry + AWS KMS

```bash
# Deploy new contracts
just deploy amoy  # Deploy to Amoy testnet
just deploy polygon  # Deploy to Polygon mainnet

# Or manually with Foundry
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --aws --sender $(cast wallet address --aws)
```

#### Upgrade with Just + Foundry + AWS KMS

```bash
# Upgrade VMahout (builds reference automatically)
just upgrade-vmahout amoy  # Upgrade on Amoy testnet
just upgrade-vmahout polygon  # Upgrade on Polygon mainnet

# Upgrade PropertyDataConsensus (builds reference automatically)
just upgrade-consensus amoy  # Upgrade on Amoy testnet
just upgrade-consensus polygon  # Upgrade on Polygon mainnet

# Or manually with Foundry (must build reference first)
just build-reference
VMAHOUT_PROXY=0x... forge script script/UpgradeVMahout.s.sol --rpc-url $RPC_URL --broadcast --aws
```

#### Dry Run (no broadcast)

```bash
# Test upgrade without broadcasting
just build-reference
forge script script/UpgradeVMahout.s.sol --rpc-url $RPC_URL --aws --sender $(cast wallet address --aws)
```

### AWS KMS Commands

```bash
# Get address from AWS KMS key
cast wallet address --aws

# Send transaction with AWS KMS
cast send $CONTRACT_ADDRESS "functionName()" --aws --rpc-url $RPC_URL

# Sign message with AWS KMS
cast wallet sign "message" --aws
```

### Contract Verification

```bash
# Verify contract on Etherscan
forge verify-contract $ADDRESS VMahout --chain polygon --etherscan-api-key $POLYGONSCAN_API_KEY
```

## CI/CD

The project uses GitHub Actions for CI/CD:

- **PR Checks**: Runs tests and dry-run upgrades on pull requests
- **Release**: Deploys upgrades to mainnet on merge to main branch

Both workflows use AWS KMS for secure key management without exposing private keys.

## Contract Addresses

### Polygon Mainnet

- VMahout Proxy: `0x3b3ad74fF6840fA5Ff5E65b551fC5E8ed13c3F18`
- PropertyDataConsensus Proxy: `0x525E59e4DE2B51f52B9e30745a513E407652AB7c`

### Test Addresses (CI)

- VMahout Proxy: `0x724d3E7e0da94DF12793F7Fbce46388C293C572E`
- PropertyDataConsensus Proxy: `0x9bA70DA0Fcc5619C80b817276eBb94a4b59b2D18`

## Security

- All deployments use AWS KMS for key management
- No private keys are stored in the repository
- Upgrades are protected by role-based access control
- All contracts are upgradeable using UUPS pattern

## Troubleshooting

### Common Issues

1. **Compilation errors**: Ensure remappings are correct in `foundry.toml`
2. **AWS KMS access**: Verify IAM role has correct permissions
3. **Symlink issues**: Use absolute paths if relative symlinks fail
4. **Version conflicts**: Ensure Solidity versions match between Hardhat and Foundry

### Verification Steps

```bash
# Test AWS KMS access
cast wallet address --aws

# Test compilation
forge build

# Test scripts
forge script script/Deploy.s.sol

# Test Hardhat compatibility
npx hardhat test
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

## License

ISC
