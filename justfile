# Minimal Justfile

default:
    @just --list

# Compile contracts
build:
    forge build

# Deterministic deploy using KMS signer (AWS) via Create2 salts in script
deploy:
    #!/usr/bin/env bash
    set -euo pipefail

    forge clean
    forge build

    forge script script/Deploy.s.sol \
        --rpc-url ${RPC_URL:-$POLYGON_MAINNET_RPC_URL} \
        --broadcast \
        --verify \
        --etherscan-api-key $POLYGONSCAN_API_KEY \
        --aws \
        --sender $(cast wallet address --aws) \
        --slow \
        -vvvv
