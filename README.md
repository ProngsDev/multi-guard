# Multi-Guard

A secure multi-signature wallet system built with Solidity and Foundry.

## Features

- **Multi-signature wallets** with customizable thresholds
- **Factory pattern** for easy wallet deployment
- **CREATE2 deterministic addresses** for predictable wallet addresses
- **Comprehensive testing** with 52 passing tests
- **Gas optimized** contracts

## Quick Start

### 1. Setup

```bash
# Install dependencies
forge install

# Copy environment template
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` file:
```bash
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
DEPLOYER_PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 3. Deploy

```bash
# Deploy to Sepolia testnet
./deploy.sh sepolia

# Deploy to mainnet
./deploy.sh mainnet
```

## Testing

```bash
# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report
```

## Usage

After deployment, you can create wallets using the factory:

```solidity
// Example: Create a 2-of-3 multisig wallet
address[] memory owners = new address[](3);
owners[0] = 0x...;
owners[1] = 0x...;
owners[2] = 0x...;

address wallet = factory.createWallet(owners, 2);
```

## Contract Addresses

### Sepolia Testnet
- Factory: `Not deployed yet`

### Mainnet
- Factory: `Not deployed yet`

## Security

- ✅ Comprehensive test coverage
- ✅ No admin functions or upgrades
- ✅ Immutable contracts after deployment
- ✅ CREATE2 deterministic addresses

## License

MIT
