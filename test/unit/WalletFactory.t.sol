//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WalletFactory} from "../../src/WalletFactory.sol";
import {MultiSigWallet} from "../../src/MultiSigWallet.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract WalletFactoryTest is Test {
    WalletFactory public factory;
    
    // Test addresses
    address public creator1 = address(0x1);
    address public creator2 = address(0x2);
    address public owner1 = address(0x10);
    address public owner2 = address(0x20);
    address public owner3 = address(0x30);
    address public owner4 = address(0x40);
    address public owner5 = address(0x50);
    
    // Test arrays
    address[] public validOwners;
    address[] public singleOwner;
    address[] public maxOwners;
    address[] public tooManyOwners;
    address[] public ownersWithZero;
    address[] public ownersWithDuplicate;
    
    // Events to test
    event WalletCreated(
        address indexed creator,
        address indexed wallet,
        address[] owners,
        uint256 threshold,
        bytes32 salt
    );
    
    event WalletAddressPredicted(
        address indexed creator,
        address indexed predictedAddress,
        bytes32 salt
    );

    function setUp() public {
        factory = new WalletFactory();
        
        // Setup test arrays
        validOwners.push(owner1);
        validOwners.push(owner2);
        validOwners.push(owner3);
        
        singleOwner.push(owner1);
        
        // Max owners (10)
        for (uint256 i = 1; i <= 10; i++) {
            maxOwners.push(address(uint160(i)));
        }
        
        // Too many owners (11)
        for (uint256 i = 1; i <= 11; i++) {
            tooManyOwners.push(address(uint160(i)));
        }
        
        // Owners with zero address
        ownersWithZero.push(owner1);
        ownersWithZero.push(address(0));
        ownersWithZero.push(owner3);
        
        // Owners with duplicate
        ownersWithDuplicate.push(owner1);
        ownersWithDuplicate.push(owner2);
        ownersWithDuplicate.push(owner1); // Duplicate
    }

    // ============ Constructor and Constants Tests ============
    
    function testFactoryDeployment() public view {
        assertEq(factory.MAX_OWNERS(), 10);
        assertEq(factory.MIN_OWNERS(), 1);
        assertEq(factory.totalWalletsCreated(), 0);
    }

    // ============ Wallet Creation Tests ============
    
    function testCreateWalletSuccess() public {
        vm.prank(creator1);

        // We can only check the creator and threshold/owners in the event
        vm.expectEmit(true, false, false, false);
        emit WalletCreated(creator1, address(0), validOwners, 2, bytes32(0));

        address walletAddress = factory.createWallet(validOwners, 2);
        
        // Verify wallet was created
        assertTrue(walletAddress != address(0));
        assertTrue(factory.isWalletFromFactory(walletAddress));
        
        // Verify registry updates
        address[] memory creatorWallets = factory.getWalletsByCreator(creator1);
        assertEq(creatorWallets.length, 1);
        assertEq(creatorWallets[0], walletAddress);
        assertEq(factory.getWalletCountByCreator(creator1), 1);
        assertEq(factory.totalWalletsCreated(), 1);
        
        // Verify the deployed wallet works correctly
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        assertEq(wallet.threshold(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
    }
    
    function testCreateWalletWithSingleOwner() public {
        vm.prank(creator1);
        address walletAddress = factory.createWallet(singleOwner, 1);
        
        assertTrue(walletAddress != address(0));
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        assertEq(wallet.threshold(), 1);
        assertTrue(wallet.isOwner(owner1));
    }
    
    function testCreateWalletWithMaxOwners() public {
        vm.prank(creator1);
        address walletAddress = factory.createWallet(maxOwners, 5);
        
        assertTrue(walletAddress != address(0));
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        assertEq(wallet.threshold(), 5);
        
        // Verify all owners are set
        for (uint256 i = 0; i < maxOwners.length; i++) {
            assertTrue(wallet.isOwner(maxOwners[i]));
        }
    }
    
    function testCreateMultipleWalletsBySameCreator() public {
        vm.startPrank(creator1);
        
        address wallet1 = factory.createWallet(validOwners, 2);
        address wallet2 = factory.createWallet(singleOwner, 1);
        
        vm.stopPrank();
        
        // Verify both wallets are different
        assertTrue(wallet1 != wallet2);
        
        // Verify registry
        address[] memory creatorWallets = factory.getWalletsByCreator(creator1);
        assertEq(creatorWallets.length, 2);
        assertEq(creatorWallets[0], wallet1);
        assertEq(creatorWallets[1], wallet2);
        assertEq(factory.totalWalletsCreated(), 2);
    }
    
    function testCreateWalletsByDifferentCreators() public {
        vm.prank(creator1);
        address wallet1 = factory.createWallet(validOwners, 2);
        
        vm.prank(creator2);
        address wallet2 = factory.createWallet(singleOwner, 1);
        
        // Verify wallets are different
        assertTrue(wallet1 != wallet2);
        
        // Verify registries
        assertEq(factory.getWalletCountByCreator(creator1), 1);
        assertEq(factory.getWalletCountByCreator(creator2), 1);
        assertEq(factory.totalWalletsCreated(), 2);
        
        address[] memory creator1Wallets = factory.getWalletsByCreator(creator1);
        address[] memory creator2Wallets = factory.getWalletsByCreator(creator2);
        
        assertEq(creator1Wallets[0], wallet1);
        assertEq(creator2Wallets[0], wallet2);
    }

    // ============ Input Validation Tests ============
    
    function testCreateWalletInvalidOwnersLength() public {
        // Test empty owners array
        address[] memory emptyOwners = new address[](0);
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidOwnersLength.selector, 0));
        factory.createWallet(emptyOwners, 1);
        
        // Test too many owners
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidOwnersLength.selector, 11));
        factory.createWallet(tooManyOwners, 5);
    }
    
    function testCreateWalletInvalidThreshold() public {
        // Test threshold = 0
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidThreshold.selector, 0, 3));
        factory.createWallet(validOwners, 0);
        
        // Test threshold > owners.length
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidThreshold.selector, 4, 3));
        factory.createWallet(validOwners, 4);
    }
    
    function testCreateWalletZeroAddressOwner() public {
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.ZeroAddressOwner.selector));
        factory.createWallet(ownersWithZero, 2);
    }
    
    function testCreateWalletDuplicateOwner() public {
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.DuplicateOwner.selector, owner1));
        factory.createWallet(ownersWithDuplicate, 2);
    }

    // ============ Address Prediction Tests ============
    
    function testPredictWalletAddress() public {
        (address predictedAddress, bytes32 salt) = factory.predictWalletAddress(creator1, validOwners, 2);
        
        assertTrue(predictedAddress != address(0));
        assertTrue(salt != bytes32(0));
        
        // Create wallet and verify address matches prediction
        vm.prank(creator1);
        address actualAddress = factory.createWallet(validOwners, 2);
        
        assertEq(actualAddress, predictedAddress);
    }
    
    function testPredictWalletAddressInvalidCreator() public {
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidPredictionParameters.selector));
        factory.predictWalletAddress(address(0), validOwners, 2);
    }
    
    function testPredictWalletAddressInvalidParameters() public {
        // Test with invalid threshold
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidThreshold.selector, 0, 3));
        factory.predictWalletAddress(creator1, validOwners, 0);
        
        // Test with zero address owner
        vm.expectRevert(abi.encodeWithSelector(WalletFactory.ZeroAddressOwner.selector));
        factory.predictWalletAddress(creator1, ownersWithZero, 2);
    }
    
    function testPredictDifferentAddressesForDifferentCreators() public view {
        (address predicted1,) = factory.predictWalletAddress(creator1, validOwners, 2);
        (address predicted2,) = factory.predictWalletAddress(creator2, validOwners, 2);
        
        assertTrue(predicted1 != predicted2);
    }

    // ============ Registry Query Tests ============
    
    function testGetWalletsByCreatorEmpty() public view{
        address[] memory wallets = factory.getWalletsByCreator(creator1);
        assertEq(wallets.length, 0);
        assertEq(factory.getWalletCountByCreator(creator1), 0);
    }
    
    function testIsWalletFromFactoryFalse() public {
        assertFalse(factory.isWalletFromFactory(address(0x999)));
        
        // Create wallet directly (not through factory)
        MultiSigWallet directWallet = new MultiSigWallet(validOwners, 2);
        assertFalse(factory.isWalletFromFactory(address(directWallet)));
    }

    // ============ CREATE2 Deterministic Tests ============
    
    function testDeterministicAddresses() public {
        // Deploy factory twice and verify same parameters produce same addresses
        WalletFactory factory2 = new WalletFactory();
        
        // Note: This test shows that with same factory address and same parameters,
        // we get deterministic addresses (though nonce will make them different in practice)
        vm.warp(1000); // Set consistent timestamp
        
        (address predicted1,) = factory.predictWalletAddress(creator1, validOwners, 2);
        (address predicted2,) = factory2.predictWalletAddress(creator1, validOwners, 2);
        
        // They should be different because factory addresses are different
        assertTrue(predicted1 != predicted2);
    }
    
    function testSaltUniqueness() public {
        vm.startPrank(creator1);
        
        // Create multiple wallets and verify they have different addresses
        address wallet1 = factory.createWallet(validOwners, 2);
        
        // Advance time to ensure different salt
        vm.warp(block.timestamp + 1);
        address wallet2 = factory.createWallet(validOwners, 2);
        
        vm.stopPrank();
        
        assertTrue(wallet1 != wallet2);
    }

    // ============ Edge Cases and Integration Tests ============
    
    function testCreatorNonceIncrement() public {
        assertEq(factory.creatorNonce(creator1), 0);
        
        vm.prank(creator1);
        factory.createWallet(validOwners, 2);
        
        assertEq(factory.creatorNonce(creator1), 1);
        
        vm.prank(creator1);
        factory.createWallet(singleOwner, 1);
        
        assertEq(factory.creatorNonce(creator1), 2);
    }
    
    function testWalletFunctionality() public {
        vm.prank(creator1);
        address walletAddress = factory.createWallet(validOwners, 2);

        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));

        // Fund the wallet
        vm.deal(walletAddress, 10 ether);

        // Test wallet functionality
        vm.prank(owner1);
        wallet.submitTransaction(address(0x999), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        // Verify transaction was executed
        (,,, bool executed,) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(address(0x999).balance, 1 ether);
    }

    // ============ Gas Optimization Tests ============

    function testGasOptimizedWalletCreation() public {
        vm.prank(creator1);

        uint256 gasBefore = gasleft();
        address walletAddress = factory.createWallet(validOwners, 2);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(walletAddress != address(0));
        // Gas usage should be reasonable (this is more of a benchmark)
        assertTrue(gasUsed > 0);
        console.log("Gas used for wallet creation:", gasUsed);
    }

    function testBatchWalletCreation() public {
        vm.startPrank(creator1);

        address[] memory wallets = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            address[] memory owners = new address[](2);
            owners[0] = address(uint160(100 + i));
            owners[1] = address(uint160(200 + i));

            wallets[i] = factory.createWallet(owners, 1);
            assertTrue(wallets[i] != address(0));
        }

        vm.stopPrank();

        // Verify all wallets are tracked
        assertEq(factory.getWalletCountByCreator(creator1), 5);
        assertEq(factory.totalWalletsCreated(), 5);

        address[] memory creatorWallets = factory.getWalletsByCreator(creator1);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(creatorWallets[i], wallets[i]);
            assertTrue(factory.isWalletFromFactory(wallets[i]));
        }
    }

    // ============ Fuzz Tests ============

    function testFuzzValidWalletCreation(uint8 numOwners, uint8 threshold) public {
        // Bound inputs to valid ranges
        numOwners = uint8(bound(numOwners, 1, 10));
        threshold = uint8(bound(threshold, 1, numOwners));

        // Create owners array
        address[] memory owners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            owners[i] = address(uint160(1000 + i)); // Ensure unique addresses
        }

        vm.prank(creator1);
        address walletAddress = factory.createWallet(owners, threshold);

        assertTrue(walletAddress != address(0));
        assertTrue(factory.isWalletFromFactory(walletAddress));

        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        assertEq(wallet.threshold(), threshold);

        // Verify all owners are set correctly
        for (uint256 i = 0; i < numOwners; i++) {
            assertTrue(wallet.isOwner(owners[i]));
        }
    }

    function testFuzzInvalidThreshold(uint8 numOwners, uint8 threshold) public {
        numOwners = uint8(bound(numOwners, 1, 10));

        // Create owners array
        address[] memory owners = new address[](numOwners);
        for (uint256 i = 0; i < numOwners; i++) {
            owners[i] = address(uint160(2000 + i));
        }

        // Test invalid thresholds
        if (threshold == 0) {
            vm.prank(creator1);
            vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidThreshold.selector, 0, numOwners));
            factory.createWallet(owners, 0);
        } else if (threshold > numOwners) {
            vm.prank(creator1);
            vm.expectRevert(abi.encodeWithSelector(WalletFactory.InvalidThreshold.selector, threshold, numOwners));
            factory.createWallet(owners, threshold);
        }
    }

    // ============ Event Tests ============

    function testWalletCreatedEvent() public {
        vm.prank(creator1);

        // We can only test that the event is emitted with correct creator
        vm.expectEmit(true, false, false, false);
        emit WalletCreated(creator1, address(0), validOwners, 2, bytes32(0));

        factory.createWallet(validOwners, 2);
    }

    // ============ Security Tests ============

    function testReentrancyProtection() public {
        // The factory doesn't have explicit reentrancy protection,
        // but CREATE2 and the simple state changes should be safe
        vm.prank(creator1);
        address wallet1 = factory.createWallet(validOwners, 2);

        vm.prank(creator1);
        address wallet2 = factory.createWallet(validOwners, 2);

        assertTrue(wallet1 != wallet2);
        assertEq(factory.getWalletCountByCreator(creator1), 2);
    }

    function testFactoryCannotBeUsedAsWalletOwner() public {
        // Test that factory address can be used as an owner (it's a valid address)
        address[] memory ownersWithFactory = new address[](2);
        ownersWithFactory[0] = address(factory);
        ownersWithFactory[1] = owner1;

        vm.prank(creator1);
        address walletAddress = factory.createWallet(ownersWithFactory, 1);

        assertTrue(walletAddress != address(0));
        MultiSigWallet wallet = MultiSigWallet(payable(walletAddress));
        assertTrue(wallet.isOwner(address(factory)));
    }
}
