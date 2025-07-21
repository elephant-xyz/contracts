# Justfile for vMahout project

# Default recipe
default:
    @just --list

# Install dependencies
install:
    forge install

# Build contracts
build:
    forge build

# Run tests
test:
    forge test

# Build reference contracts for upgrade validation
build-reference:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Building reference contracts for upgrade validation..."
    
    # Save current state
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    CURRENT_COMMIT=$(git rev-parse HEAD)
    
    # Ensure we have a clean working directory
    if [[ -n $(git status --porcelain) ]]; then
        echo "Error: Working directory is not clean. Please commit or stash your changes."
        exit 1
    fi
    
    # Create reference build directory
    mkdir -p previous-builds/foundry-v1
    
    # Determine reference commit
    if [[ "$CURRENT_BRANCH" == "main" ]]; then
        echo "On main branch, using previous commit as reference..."
        REFERENCE_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "")
        
        if [[ -z "$REFERENCE_COMMIT" ]]; then
            echo "Warning: No previous commit found. Skipping reference build."
            echo "This is expected for the first deployment."
            exit 0
        fi
    else
        echo "On feature branch, using main branch as reference..."
        REFERENCE_COMMIT=$(git rev-parse origin/main 2>/dev/null || echo "")
        
        if [[ -z "$REFERENCE_COMMIT" ]]; then
            echo "Warning: No main branch found. Skipping reference build."
            exit 0
        fi
    fi
    
    echo "Reference commit: $REFERENCE_COMMIT"
    
    # Checkout reference commit
    git checkout $REFERENCE_COMMIT
    
    # Check if reference commit has Foundry setup
    if [[ -f "foundry.toml" ]]; then
        echo "Reference commit has Foundry setup, building with Forge..."
        forge build --build-info --build-info-path previous-builds/foundry-v1
    else
        echo "Warning: No Foundry setup found in reference commit. Skipping reference build."
    fi
    
    # Return to original state
    git checkout $CURRENT_COMMIT
    
    echo "Reference build process completed!"

# Deploy contracts
deploy network="amoy":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first
    just build-reference
    
    # Build current contracts
    forge build
    
    # Run deployment
    forge script script/Deploy.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        -vvvv

# Upgrade VMahout contract (local)
upgrade-vmahout-local:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run upgrade
    forge script script/UpgradeVMahout.s.sol \
        --rpc-url http://localhost:8545 \
        --broadcast \
        -vvvv

# Upgrade VMahout contract
upgrade-vmahout network="amoy":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run upgrade
    forge script script/UpgradeVMahout.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        -vvvv

# Upgrade PropertyDataConsensus contract (local)
upgrade-consensus-local:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run upgrade
    forge script script/UpgradeConsensus.s.sol \
        --rpc-url http://localhost:8545 \
        --broadcast \
        -vvvv

# Upgrade PropertyDataConsensus contract
upgrade-consensus network="amoy":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run upgrade
    forge script script/UpgradeConsensus.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        -vvvv

# Clean build artifacts
clean:
    rm -rf out cache artifacts
    rm -rf previous-builds

# Format code
format:
    forge fmt

# Run linter
lint:
    forge fmt --check

# Run all checks (for CI)
check:
    just lint
    just build
    just test

# Dry run upgrade PropertyDataConsensus (for CI)
upgrade-consensus-dry-run network="polygon":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run dry run upgrade
    SKIP_VALIDATION=${SKIP_VALIDATION:-false} forge script script/UpgradeConsensus.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        --etherscan-api-key $POLYGONSCAN_API_KEY \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow \
        -vvvv

# Dry run upgrade VMahout (for CI)
upgrade-vmahout-dry-run network="polygon":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first (unless skipping validation)
    if [[ "${SKIP_VALIDATION:-false}" != "true" ]]; then
        just build-reference
    fi
    
    # Build current contracts
    forge build
    
    # Run dry run upgrade
    forge script script/UpgradeVMahout.s.sol \
        --rpc-url {{network}} \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow

# Production upgrade PropertyDataConsensus (for release)
upgrade-consensus-prod network="polygon":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first
    just build-reference
    
    # Build current contracts
    forge build
    
    # Run production upgrade
    forge script script/UpgradeConsensus.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        --etherscan-api-key $POLYGONSCAN_API_KEY \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow \
        -vvvv

# Production upgrade VMahout (for release)
upgrade-vmahout-prod network="polygon":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first
    just build-reference
    
    # Build current contracts
    forge build
    
    # Run production upgrade
    forge script script/UpgradeVMahout.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        --etherscan-api-key $POLYGONSCAN_API_KEY \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow \
        -vvvv

# Grant LEXICON_ORACLE_MANAGER_ROLE
grant-roles network="polygon":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build contracts
    forge build
    
    # Run grant roles script
    forge script script/GrantRoles.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        --etherscan-api-key $POLYGONSCAN_API_KEY \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow \
        -vvvv
