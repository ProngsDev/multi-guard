//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {console} from "forge-std/console.sol";

/**
 * @title ExampleWalletCreation
 * @notice Example script demonstrating WalletFactory usage
 * @dev This script shows how to:
 *      1. Predict wallet addresses
 *      2. Create wallets
 *      3. Query factory registry
 *      4. Use deployed wallets
 */
contract ExampleWalletCreation is Script {
    // Example addresses (replace with real addresses for actual deployment)
    address constant FACTORY_ADDRESS = 0x1234567890123456789012345678901234567890; // Replace with actual factory address
    address constant OWNER1 = 0x1111111111111111111111111111111111111111;
    address constant OWNER2 = 0x2222222222222222222222222222222222222222;
    address constant OWNER3 = 0x3333333333333333333333333333333333333333;
    
    function run() external {
        // Get the factory instance
        WalletFactory factory = WalletFactory(FACTORY_ADDRESS);
        
        // Setup wallet parameters
        address[] memory owners = new address[](3);
        owners[0] = OWNER1;
        owners[1] = OWNER2;
        owners[2] = OWNER3;
        uint256 threshold = 2;
        
        console.log("=== WalletFactory Example Usage ===");
        console.log("Factory address:", address(factory));
        console.log("Creator address:", msg.sender);
        
        // Step 1: Predict wallet address
        console.log("\n1. Predicting wallet address...");
        (address predictedAddress, bytes32 salt) = factory.predictWalletAddress(
            msg.sender,
            owners,
            threshold
        );
        console.log("Predicted address:", predictedAddress);
        console.log("Salt:", vm.toString(salt));
        
        // Step 2: Create the wallet
        console.log("\n2. Creating wallet...");
        vm.startBroadcast();
        
        address walletAddress = factory.createWallet(owners, threshold);
        
        vm.stopBroadcast();
        
        console.log("Wallet created at:", walletAddress);
        console.log("Address matches prediction:", walletAddress == predictedAddress);
        
        // Step 3: Query factory registry
        console.log("\n3. Querying factory registry...");
        address[] memory creatorWallets = factory.getWalletsByCreator(msg.sender);
        console.log("Number of wallets created by sender:", creatorWallets.length);
        console.log("Is wallet from factory:", factory.isWalletFromFactory(walletAddress));
        console.log("Total wallets created:", factory.totalWalletsCreated());
        
        // Step 4: Verify wallet functionality
        console.log("\n4. Verifying wallet functionality...");
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        console.log("Wallet threshold:", wallet.threshold());
        console.log("Owner1 is owner:", wallet.isOwner(OWNER1));
        console.log("Owner2 is owner:", wallet.isOwner(OWNER2));
        console.log("Owner3 is owner:", wallet.isOwner(OWNER3));
        
        // Step 5: Example of creating multiple wallets
        console.log("\n5. Creating additional wallets...");
        
        // Create a single-owner wallet
        address[] memory singleOwner = new address[](1);
        singleOwner[0] = OWNER1;
        
        vm.startBroadcast();
        address singleOwnerWallet = factory.createWallet(singleOwner, 1);
        vm.stopBroadcast();
        
        console.log("Single-owner wallet created at:", singleOwnerWallet);
        
        // Create a high-threshold wallet
        address[] memory manyOwners = new address[](5);
        manyOwners[0] = OWNER1;
        manyOwners[1] = OWNER2;
        manyOwners[2] = OWNER3;
        manyOwners[3] = address(0x4444444444444444444444444444444444444444);
        manyOwners[4] = address(0x5555555555555555555555555555555555555555);
        
        vm.startBroadcast();
        address highThresholdWallet = factory.createWallet(manyOwners, 4);
        vm.stopBroadcast();
        
        console.log("High-threshold wallet created at:", highThresholdWallet);
        
        // Final registry check
        console.log("\n6. Final registry status...");
        address[] memory finalWallets = factory.getWalletsByCreator(msg.sender);
        console.log("Total wallets created by sender:", finalWallets.length);
        console.log("Total wallets in factory:", factory.totalWalletsCreated());
        
        for (uint256 i = 0; i < finalWallets.length; i++) {
            console.log("Wallet", i + 1, ":", finalWallets[i]);
        }
        
        console.log("\n=== Example completed successfully! ===");
    }
    
    /**
     * @notice Helper function to demonstrate wallet usage after creation
     * @param walletAddress Address of the created wallet
     */
    function demonstrateWalletUsage(address walletAddress) external {
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        
        console.log("\n=== Demonstrating Wallet Usage ===");
        console.log("Wallet address:", walletAddress);
        
        // Fund the wallet for demonstration
        vm.deal(walletAddress, 10 ether);
        console.log("Wallet balance:", walletAddress.balance);
        
        vm.startBroadcast();
        
        // Submit a transaction
        wallet.submitTransaction(address(0x9999999999999999999999999999999999999999), 1 ether, "");
        console.log("Transaction submitted");
        
        // Confirm the transaction (assuming msg.sender is an owner)
        wallet.confirmTransaction(0);
        console.log("Transaction confirmed by sender");
        
        vm.stopBroadcast();
        
        // Check transaction status
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = wallet.transactions(0);
        console.log("Transaction to:", to);
        console.log("Transaction value:", value);
        console.log("Transaction executed:", executed);
        console.log("Number of confirmations:", numConfirmations);
        console.log("Required confirmations:", wallet.threshold());
        
        console.log("=== Wallet usage demonstration completed ===");
    }
}
