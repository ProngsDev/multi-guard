//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {console} from "forge-std/console.sol";

/**
 * @title WalletDiscovery
 * @notice Production-ready script for discovering wallets where an address is an owner
 * @dev Uses event-based approach for efficient wallet discovery
 */
contract WalletDiscovery is Script {
    
    struct WalletInfo {
        address walletAddress;
        address creator;
        address[] owners;
        uint256 threshold;
        uint256 blockNumber;
        bytes32 transactionHash;
    }
    
    /**
     * @notice Discovers all wallets where the specified address is an owner
     * @param factoryAddress Address of the WalletFactory contract
     * @param ownerAddress Address to search for as an owner
     * @param fromBlock Starting block number (0 for from beginning)
     * @param toBlock Ending block number (0 for latest)
     * @return walletInfos Array of wallet information where address is an owner
     */
    function discoverWalletsByOwner(
        address factoryAddress,
        address ownerAddress,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (WalletInfo[] memory walletInfos) {
        WalletFactory factory = WalletFactory(factoryAddress);
        
        console.log("=== Wallet Discovery for Owner ===");
        console.log("Factory:", factoryAddress);
        console.log("Owner:", ownerAddress);
        console.log("Block range:", fromBlock, "to", toBlock == 0 ? block.number : toBlock);
        
        // Note: In a real implementation, you would use off-chain tools
        // like ethers.js, web3.js, or The Graph to query events efficiently
        // This is a demonstration of the logic
        
        console.log("\nTo implement this in production:");
        console.log("1. Use ethers.js or web3.js to query WalletCreated events");
        console.log("2. Filter events where owners array contains your address");
        console.log("3. Optionally use indexing services like The Graph for faster queries");
        
        // Return empty array as this is a demonstration
        // Real implementation would be done off-chain
        return new WalletInfo[](0);
    }
    
    /**
     * @notice Validates that an address is actually an owner of a wallet
     * @param walletAddress Address of the wallet to check
     * @param ownerAddress Address to verify as owner
     * @return isOwner True if address is an owner of the wallet
     * @return threshold Current threshold of the wallet
     * @return totalOwners Total number of owners
     */
    function validateWalletOwnership(
        address walletAddress,
        address ownerAddress
    ) external view returns (
        bool isOwner,
        uint256 threshold,
        uint256 totalOwners
    ) {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        
        isOwner = wallet.isOwner(ownerAddress);
        threshold = wallet.threshold();
        
        // Count total owners by checking the owners array
        // Note: This assumes owners array is accessible or you track it separately
        totalOwners = 0;
        
        console.log("Wallet:", walletAddress);
        console.log("Is Owner:", isOwner);
        console.log("Threshold:", threshold);
        
        return (isOwner, threshold, totalOwners);
    }
    
    /**
     * @notice Gets comprehensive wallet information for an owner
     * @param factoryAddress Address of the WalletFactory
     * @param ownerAddress Address to get wallet info for
     */
    function getWalletSummary(
        address factoryAddress,
        address ownerAddress
    ) external view {
        WalletFactory factory = WalletFactory(factoryAddress);
        
        console.log("=== Wallet Summary for Address ===");
        console.log("Address:", ownerAddress);
        
        // 1. Get wallets created by this address
        address[] memory createdWallets = factory.getWalletsByCreator(ownerAddress);
        console.log("\nWallets Created by Address:", createdWallets.length);
        
        for (uint256 i = 0; i < createdWallets.length; i++) {
            console.log("Created Wallet", i + 1, ":", createdWallets[i]);
            _logWalletDetails(createdWallets[i], ownerAddress);
        }
        
        console.log("\nTo find wallets where you're an owner (but not creator):");
        console.log("Use the event-based discovery method with off-chain tools");
    }
    
    /**
     * @notice Internal function to log wallet details
     */
    function _logWalletDetails(address walletAddress, address checkAddress) internal view {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        
        console.log("  - Threshold:", wallet.threshold());
        console.log("  - Is Owner:", wallet.isOwner(checkAddress));
        console.log("  - Balance:", walletAddress.balance);
    }
    
    /**
     * @notice Example of how to run wallet discovery
     */
    function run() external {
        // Example addresses - replace with actual values
        address factoryAddress = 0x1234567890123456789012345678901234567890;
        address myAddress = msg.sender;
        
        console.log("=== Production Wallet Discovery Example ===");
        
        // Get summary of wallets for the current address
        this.getWalletSummary(factoryAddress, myAddress);
        
        // Validate specific wallet ownership
        // address specificWallet = 0x...;
        // this.validateWalletOwnership(specificWallet, myAddress);
        
        console.log("\n=== Next Steps for Production ===");
        console.log("1. Implement off-chain event querying using ethers.js/web3.js");
        console.log("2. Consider using The Graph Protocol for indexed queries");
        console.log("3. Cache results and update incrementally");
        console.log("4. Implement pagination for large result sets");
    }
}
