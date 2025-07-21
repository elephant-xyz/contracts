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
    
    # Check if reference commit has Foundry or Hardhat setup
    if [[ -f "foundry.toml" ]]; then
        echo "Reference commit has Foundry setup, building with Forge..."
        forge build --build-info --build-info-path previous-builds/build-info-v1
    elif [[ -f "hardhat.config.ts" ]] || [[ -f "hardhat.config.js" ]]; then
        echo "Reference commit has Hardhat setup, building with Hardhat..."
        
        # Install dependencies if needed
        if [[ ! -d "node_modules" ]]; then
            echo "Installing dependencies..."
            npm install
        fi
        
        # Build with Hardhat
        npx hardhat compile
        
        # Copy entire Hardhat artifacts to our reference directory
        # This ensures we have all the necessary files for validation
        if [[ -d "artifacts" ]]; then
            mkdir -p previous-builds
            mkdir -p previous-builds/artifacts-v1
            mkdir -p previous-builds/build-info-v1
            
            # Copy entire artifacts directory
            cp -r artifacts/build-info/ previous-builds/build-info-v1/build-info
            
            echo "Copied Hardhat artifacts to reference directory"
        else
            echo "Warning: No Hardhat artifacts found"
        fi
    else
        echo "Warning: No build system found in reference commit. Skipping reference build."
    fi
    
    # Return to original state
    git checkout $CURRENT_COMMIT
    
    # Restore node_modules if they were removed by checkout
    if [[ -f "package.json" ]] && [[ ! -d "node_modules" ]]; then
        echo "Restoring node_modules..."
        npm install
    fi
    
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
