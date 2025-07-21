# Justfile for vMahout project

# Default recipe
default:
    @just --list

# Install dependencies
install:
    forge install
    npm install

# Build contracts
build:
    forge build

# Run tests
test:
    npm test

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
    mkdir -p previous-builds/build-info-v1
    
    # Determine reference commit
    if [[ "$CURRENT_BRANCH" == "main" ]]; then
        echo "On main branch, using previous commit as reference..."
        REFERENCE_COMMIT=$(git rev-parse HEAD~1)
    else
        echo "On feature branch, using main branch as reference..."
        REFERENCE_COMMIT=$(git rev-parse origin/main)
    fi
    
    echo "Reference commit: $REFERENCE_COMMIT"
    
    # Checkout reference commit
    git checkout $REFERENCE_COMMIT
    
    # Build reference contracts
    forge build --build-info --build-info-path previous-builds/build-info-v1
    
    # Return to original state
    git checkout $CURRENT_COMMIT
    
    echo "Reference contracts built successfully!"

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

# Upgrade VMahout contract
upgrade-vmahout network="amoy":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first
    just build-reference
    
    # Build current contracts
    forge build
    
    # Run upgrade
    forge script script/UpgradeVMahout.s.sol \
        --rpc-url {{network}} \
        --broadcast \
        --verify \
        -vvvv

# Upgrade PropertyDataConsensus contract
upgrade-consensus network="amoy":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build reference first
    just build-reference
    
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
    rm -rf out cache artifacts node_modules
    rm -rf previous-builds

# Format code
format:
    forge fmt

# Run linter
lint:
    npm run lint

# Run all checks (for CI)
check:
    just format
    just lint
    just build
    just test