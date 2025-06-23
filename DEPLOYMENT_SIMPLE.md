# Simple Deployment Guide

## Setup

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values:**
   ```bash
   SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
   MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
   DEPLOYER_PRIVATE_KEY=your_private_key_here
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

## Deploy

```bash
# Deploy to Sepolia testnet
./deploy.sh sepolia

# Deploy to mainnet (with confirmation)
./deploy.sh mainnet
```

## Test

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report
```

That's it! Simple and straightforward.
