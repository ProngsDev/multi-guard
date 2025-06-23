//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {WalletFactory} from "../src/WalletFactory.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployWalletFactory
 * @notice Deployment script for the WalletFactory contract
 * @dev Run with: forge script script/DeployWalletFactory.s.sol --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployWalletFactory is Script {
    function run() external returns (WalletFactory factory) {
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy the WalletFactory
        factory = new WalletFactory();
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("WalletFactory deployed at:", address(factory));
        console.log("Deployer:", msg.sender);
        console.log("Max owners per wallet:", factory.MAX_OWNERS());
        console.log("Min owners per wallet:", factory.MIN_OWNERS());
        
        return factory;
    }
}
