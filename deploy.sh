#!/bin/bash

# Simple deployment script for Multi-Guard

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Copy .env.example to .env and configure it."
    exit 1
fi

# Check required variables
if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo "Error: DEPLOYER_PRIVATE_KEY not set in .env"
    exit 1
fi

# Network selection
NETWORK=${1:-sepolia}

case $NETWORK in
    "sepolia")
        RPC_URL=$SEPOLIA_RPC_URL
        ;;
    "mainnet")
        RPC_URL=$MAINNET_RPC_URL
        echo "WARNING: Deploying to MAINNET!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
        ;;
    *)
        echo "Unsupported network: $NETWORK"
        echo "Supported networks: sepolia, mainnet"
        exit 1
        ;;
esac

if [ -z "$RPC_URL" ]; then
    echo "Error: RPC URL not configured for $NETWORK"
    exit 1
fi

echo "Deploying to $NETWORK..."
echo "RPC URL: $RPC_URL"

# Deploy with verification
forge script script/DeployWalletFactory.s.sol \
    --rpc-url $RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --verify

echo "Deployment complete!"
