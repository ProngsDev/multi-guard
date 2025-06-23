/**
 * Production-Ready Wallet Discovery Implementation
 * Uses event-based approach for efficient wallet querying
 */

const { ethers } = require('ethers');

class WalletDiscovery {
    constructor(provider, factoryAddress, factoryABI) {
        this.provider = provider;
        this.factory = new ethers.Contract(factoryAddress, factoryABI, provider);
        this.cache = new Map(); // Simple in-memory cache
    }

    /**
     * Discovers all wallets where the specified address is an owner
     * @param {string} ownerAddress - Address to search for as an owner
     * @param {number} fromBlock - Starting block (optional, defaults to 0)
     * @param {number} toBlock - Ending block (optional, defaults to 'latest')
     * @param {boolean} useCache - Whether to use cached results
     * @returns {Promise<Array>} Array of wallet information
     */
    async discoverWalletsByOwner(ownerAddress, fromBlock = 0, toBlock = 'latest', useCache = true) {
        const cacheKey = `${ownerAddress}-${fromBlock}-${toBlock}`;
        
        // Check cache first
        if (useCache && this.cache.has(cacheKey)) {
            console.log('📋 Using cached results');
            return this.cache.get(cacheKey);
        }

        console.log(`🔍 Discovering wallets for owner: ${ownerAddress}`);
        console.log(`📊 Scanning blocks ${fromBlock} to ${toBlock}`);

        try {
            // Query WalletCreated events
            const filter = this.factory.filters.WalletCreated();
            const events = await this.factory.queryFilter(filter, fromBlock, toBlock);
            
            console.log(`📝 Found ${events.length} total wallet creation events`);

            // Filter events where the address is an owner
            const relevantWallets = [];
            
            for (const event of events) {
                const { creator, wallet, owners, threshold } = event.args;
                
                // Check if ownerAddress is in the owners array
                const isOwner = owners.some(owner => 
                    owner.toLowerCase() === ownerAddress.toLowerCase()
                );
                
                if (isOwner) {
                    const walletInfo = {
                        walletAddress: wallet,
                        creator: creator,
                        owners: owners,
                        threshold: threshold.toString(),
                        blockNumber: event.blockNumber,
                        transactionHash: event.transactionHash,
                        isCreator: creator.toLowerCase() === ownerAddress.toLowerCase()
                    };
                    
                    // Validate the wallet still exists and owner is still valid
                    const isStillOwner = await this.validateOwnership(wallet, ownerAddress);
                    walletInfo.isCurrentOwner = isStillOwner;
                    
                    relevantWallets.push(walletInfo);
                }
            }

            console.log(`✅ Found ${relevantWallets.length} wallets where address is an owner`);

            // Cache the results
            if (useCache) {
                this.cache.set(cacheKey, relevantWallets);
            }

            return relevantWallets;

        } catch (error) {
            console.error('❌ Error discovering wallets:', error);
            throw error;
        }
    }

    /**
     * Validates that an address is currently an owner of a wallet
     * @param {string} walletAddress - Address of the wallet
     * @param {string} ownerAddress - Address to validate
     * @returns {Promise<boolean>} True if address is currently an owner
     */
    async validateOwnership(walletAddress, ownerAddress) {
        try {
            const walletABI = [
                "function isOwner(address) view returns (bool)",
                "function threshold() view returns (uint256)"
            ];
            
            const wallet = new ethers.Contract(walletAddress, walletABI, this.provider);
            return await wallet.isOwner(ownerAddress);
        } catch (error) {
            console.warn(`⚠️  Could not validate ownership for wallet ${walletAddress}:`, error.message);
            return false;
        }
    }

    /**
     * Gets comprehensive wallet information for an address
     * @param {string} address - Address to get information for
     * @returns {Promise<Object>} Comprehensive wallet information
     */
    async getWalletSummary(address) {
        console.log(`📊 Getting wallet summary for: ${address}`);

        const [createdWallets, ownedWallets] = await Promise.all([
            this.getWalletsCreatedBy(address),
            this.discoverWalletsByOwner(address)
        ]);

        const summary = {
            address: address,
            walletsCreated: createdWallets,
            walletsOwned: ownedWallets,
            totalCreated: createdWallets.length,
            totalOwned: ownedWallets.length,
            totalUnique: new Set([
                ...createdWallets.map(w => w.walletAddress),
                ...ownedWallets.map(w => w.walletAddress)
            ]).size
        };

        console.log(`📈 Summary: ${summary.totalCreated} created, ${summary.totalOwned} owned, ${summary.totalUnique} unique`);
        
        return summary;
    }

    /**
     * Gets wallets created by a specific address (using factory method)
     * @param {string} creatorAddress - Address that created wallets
     * @returns {Promise<Array>} Array of created wallet addresses
     */
    async getWalletsCreatedBy(creatorAddress) {
        try {
            const walletAddresses = await this.factory.getWalletsByCreator(creatorAddress);
            
            return walletAddresses.map(address => ({
                walletAddress: address,
                creator: creatorAddress,
                isCreator: true
            }));
        } catch (error) {
            console.error('❌ Error getting created wallets:', error);
            return [];
        }
    }

    /**
     * Monitors for new wallets where an address becomes an owner
     * @param {string} ownerAddress - Address to monitor
     * @param {Function} callback - Callback function for new wallets
     */
    startMonitoring(ownerAddress, callback) {
        console.log(`👀 Starting to monitor new wallets for: ${ownerAddress}`);

        const filter = this.factory.filters.WalletCreated();
        
        this.factory.on(filter, (creator, wallet, owners, threshold, salt, event) => {
            const isOwner = owners.some(owner => 
                owner.toLowerCase() === ownerAddress.toLowerCase()
            );
            
            if (isOwner) {
                console.log(`🆕 New wallet detected: ${wallet}`);
                
                const walletInfo = {
                    walletAddress: wallet,
                    creator: creator,
                    owners: owners,
                    threshold: threshold.toString(),
                    blockNumber: event.blockNumber,
                    transactionHash: event.transactionHash,
                    isCreator: creator.toLowerCase() === ownerAddress.toLowerCase()
                };
                
                callback(walletInfo);
            }
        });
    }

    /**
     * Stops monitoring for new wallets
     */
    stopMonitoring() {
        this.factory.removeAllListeners();
        console.log('🛑 Stopped monitoring for new wallets');
    }

    /**
     * Clears the cache
     */
    clearCache() {
        this.cache.clear();
        console.log('🗑️  Cache cleared');
    }
}

// Example usage
async function example() {
    // Initialize provider (replace with your RPC URL)
    const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
    
    // Factory contract details (replace with actual values)
    const factoryAddress = '0x...';
    const factoryABI = [
        "event WalletCreated(address indexed creator, address indexed wallet, address[] owners, uint256 threshold, bytes32 salt)",
        "function getWalletsByCreator(address creator) view returns (address[])",
        "function isWalletFromFactory(address wallet) view returns (bool)"
    ];
    
    // Create discovery instance
    const discovery = new WalletDiscovery(provider, factoryAddress, factoryABI);
    
    // Your address
    const myAddress = '0x...';
    
    try {
        // Get comprehensive summary
        const summary = await discovery.getWalletSummary(myAddress);
        console.log('📋 Wallet Summary:', summary);
        
        // Start monitoring for new wallets
        discovery.startMonitoring(myAddress, (walletInfo) => {
            console.log('🎉 You were added to a new wallet!', walletInfo);
        });
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

module.exports = { WalletDiscovery };
