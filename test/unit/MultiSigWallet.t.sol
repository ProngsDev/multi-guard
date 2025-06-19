//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MultiSigWallet} from "../../src/MultiSigWallet.sol";
import {Test} from "forge-std/Test.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet multiSigWallet;

    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public nonOwner = address(0x4);
    address public recipient = address(0x5);

    address[] public owners;
    uint256 public threshold = 2;

    // Events to test
    event TransactionSubmitted(uint256 txIndex, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 txIndex, address indexed owner);
    event TransactionExecuted(uint256 txIndex);

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        multiSigWallet = new MultiSigWallet(owners, threshold);

        // Fund the wallet with some ETH for testing
        vm.deal(address(multiSigWallet), 10 ether);
    }

    // ============ Constructor Tests ============

    function testConstructorValidParameters() public {
        address[] memory validOwners = new address[](3);
        validOwners[0] = address(0x10);
        validOwners[1] = address(0x20);
        validOwners[2] = address(0x30);

        MultiSigWallet wallet = new MultiSigWallet(validOwners, 2);

        assertEq(wallet.threshold(), 2);
        assertTrue(wallet.isOwner(address(0x10)));
        assertTrue(wallet.isOwner(address(0x20)));
        assertTrue(wallet.isOwner(address(0x30)));
    }

    function testConstructorInvalidNumberOfOwners() public {
        // Test empty owners array
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.InvalidNumberOfOwners.selector, 0));
        new MultiSigWallet(emptyOwners, 1);

        // Test too many owners (>10)
        address[] memory tooManyOwners = new address[](11);
        for (uint i = 0; i < 11; i++) {
            tooManyOwners[i] = address(uint160(i + 1));
        }
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.InvalidNumberOfOwners.selector, 11));
        new MultiSigWallet(tooManyOwners, 5);
    }

    function testConstructorInvalidThreshold() public {
        address[] memory validOwners = new address[](3);
        validOwners[0] = address(0x10);
        validOwners[1] = address(0x20);
        validOwners[2] = address(0x30);

        // Test threshold = 0
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.InvalidThreshold.selector, 0));
        new MultiSigWallet(validOwners, 0);

        // Test threshold > owners.length
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.InvalidThreshold.selector, 4));
        new MultiSigWallet(validOwners, 4);
    }

    function testConstructorZeroAddress() public {
        address[] memory invalidOwners = new address[](3);
        invalidOwners[0] = address(0x10);
        invalidOwners[1] = address(0); // Zero address
        invalidOwners[2] = address(0x30);

        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.ZeroAddress.selector));
        new MultiSigWallet(invalidOwners, 2);
    }

    function testConstructorDuplicateOwners() public {
        address[] memory duplicateOwners = new address[](3);
        duplicateOwners[0] = address(0x10);
        duplicateOwners[1] = address(0x10); // Duplicate
        duplicateOwners[2] = address(0x30);

        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.NotUnique.selector, address(0x10)));
        new MultiSigWallet(duplicateOwners, 2);
    }
    // ============ Transaction Submission Tests ============

    function testSubmitTransaction() public {
        vm.prank(owner1);

        vm.expectEmit(true, true, true, true);
        emit TransactionSubmitted(0, recipient, 1 ether, "");

        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) =
            multiSigWallet.transactions(0);

        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionOnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.NotOwner.selector));
        multiSigWallet.submitTransaction(recipient, 1 ether, "");
    }

    function testSubmitTransactionWithData() public {
        bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", recipient, 100);

        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 0, callData);

        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) =
            multiSigWallet.transactions(0);

        assertEq(to, recipient);
        assertEq(value, 0);
        assertEq(data, callData);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    // ============ Transaction Confirmation Tests ============

    function testConfirmTransaction() public {
        // Submit transaction first
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        // Confirm transaction
        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit TransactionConfirmed(0, owner1);

        multiSigWallet.confirmTransaction(0);

        assertTrue(multiSigWallet.confirmations(0, owner1));

        (, , , , uint256 numConfirmations) = multiSigWallet.transactions(0);
        assertEq(numConfirmations, 1);
    }

    function testConfirmTransactionOnlyOwner() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.NotOwner.selector));
        multiSigWallet.confirmTransaction(0);
    }

    function testConfirmNonExistentTransaction() public {
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.TxDoesNotExist.selector, 0));
        multiSigWallet.confirmTransaction(0);
    }

    function testConfirmAlreadyExecutedTransaction() public {
        // Submit and execute transaction
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner1);
        multiSigWallet.executeTransaction(0);

        // Try to confirm executed transaction
        vm.prank(owner3);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.AlreadyExecuted.selector));
        multiSigWallet.confirmTransaction(0);
    }

    function testConfirmAlreadyConfirmedTransaction() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        // Try to confirm again
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.AlreadyConfirmed.selector));
        multiSigWallet.confirmTransaction(0);
    }
    // ============ Transaction Execution Tests ============

    function testExecuteTransaction() public {
        uint256 initialBalance = recipient.balance;

        // Submit transaction
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        // Get enough confirmations
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        // Execute transaction
        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(0);

        multiSigWallet.executeTransaction(0);

        // Check transaction is marked as executed
        (, , , bool executed, ) = multiSigWallet.transactions(0);
        assertTrue(executed);

        // Check ETH was transferred
        assertEq(recipient.balance, initialBalance + 1 ether);
    }

    function testExecuteTransactionOnlyOwner() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.NotOwner.selector));
        multiSigWallet.executeTransaction(0);
    }

    function testExecuteNonExistentTransaction() public {
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.TxDoesNotExist.selector, 0));
        multiSigWallet.executeTransaction(0);
    }

    function testExecuteAlreadyExecutedTransaction() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner1);
        multiSigWallet.executeTransaction(0);

        // Try to execute again
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(MultiSigWallet.AlreadyExecuted.selector));
        multiSigWallet.executeTransaction(0);
    }

    function testExecuteTransactionInsufficientConfirmations() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        // Only one confirmation (threshold is 2)
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("Not enough confirmations");
        multiSigWallet.executeTransaction(0);
    }

    function testExecuteTransactionFailedCall() public {
        // Create a contract that will reject ETH
        RejectETH rejectContract = new RejectETH();

        vm.prank(owner1);
        multiSigWallet.submitTransaction(address(rejectContract), 1 ether, "");

        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("Transaction failed");
        multiSigWallet.executeTransaction(0);
    }

    // ============ Multiple Confirmations Test ============

    function testMultipleConfirmations() public {
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        // First confirmation
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        (, , , , uint256 numConfirmations) = multiSigWallet.transactions(0);
        assertEq(numConfirmations, 1);

        // Second confirmation
        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        (, , , , numConfirmations) = multiSigWallet.transactions(0);
        assertEq(numConfirmations, 2);

        // Third confirmation
        vm.prank(owner3);
        multiSigWallet.confirmTransaction(0);

        (, , , , numConfirmations) = multiSigWallet.transactions(0);
        assertEq(numConfirmations, 3);
    }
    // ============ Receive Function Tests ============

    function testReceiveETH() public {
        uint256 initialBalance = address(multiSigWallet).balance;

        // Send ETH to the wallet
        vm.deal(address(this), 5 ether);
        (bool success, ) = address(multiSigWallet).call{value: 2 ether}("");
        assertTrue(success);

        assertEq(address(multiSigWallet).balance, initialBalance + 2 ether);
    }

    // ============ Integration Tests ============

    function testCompleteTransactionLifecycle() public {
        uint256 initialRecipientBalance = recipient.balance;
        uint256 initialWalletBalance = address(multiSigWallet).balance;

        // 1. Submit transaction
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 2 ether, "");

        // 2. First confirmation
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);

        // 3. Second confirmation (reaches threshold)
        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);

        // 4. Execute transaction
        vm.prank(owner3);
        multiSigWallet.executeTransaction(0);

        // 5. Verify final state
        (, , , bool executed, uint256 numConfirmations) = multiSigWallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(recipient.balance, initialRecipientBalance + 2 ether);
        assertEq(address(multiSigWallet).balance, initialWalletBalance - 2 ether);
    }

    function testMultipleTransactions() public {
        // Submit multiple transactions
        vm.prank(owner1);
        multiSigWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner2);
        multiSigWallet.submitTransaction(recipient, 2 ether, "");

        vm.prank(owner3);
        multiSigWallet.submitTransaction(recipient, 3 ether, "");

        // Confirm and execute first transaction
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(0);
        vm.prank(owner2);
        multiSigWallet.confirmTransaction(0);
        vm.prank(owner1);
        multiSigWallet.executeTransaction(0);

        // Confirm second transaction but don't execute
        vm.prank(owner1);
        multiSigWallet.confirmTransaction(1);

        // Check states
        (, , , bool executed0, ) = multiSigWallet.transactions(0);
        (, , , bool executed1, ) = multiSigWallet.transactions(1);
        (, , , bool executed2, ) = multiSigWallet.transactions(2);

        assertTrue(executed0);
        assertFalse(executed1);
        assertFalse(executed2);
    }

    function testDifferentThresholds() public {
        // Test with threshold = 1
        address[] memory singleOwners = new address[](1);
        singleOwners[0] = owner1;

        MultiSigWallet singleThresholdWallet = new MultiSigWallet(singleOwners, 1);
        vm.deal(address(singleThresholdWallet), 5 ether);

        vm.prank(owner1);
        singleThresholdWallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        singleThresholdWallet.confirmTransaction(0);

        vm.prank(owner1);
        singleThresholdWallet.executeTransaction(0);

        (, , , bool executed, ) = singleThresholdWallet.transactions(0);
        assertTrue(executed);
    }

    function testMaxThreshold() public {
        // Test with threshold = number of owners (3)
        MultiSigWallet maxThresholdWallet = new MultiSigWallet(owners, 3);
        vm.deal(address(maxThresholdWallet), 5 ether);

        vm.prank(owner1);
        maxThresholdWallet.submitTransaction(recipient, 1 ether, "");

        // Need all 3 confirmations
        vm.prank(owner1);
        maxThresholdWallet.confirmTransaction(0);
        vm.prank(owner2);
        maxThresholdWallet.confirmTransaction(0);

        // Should fail with only 2 confirmations
        vm.prank(owner1);
        vm.expectRevert("Not enough confirmations");
        maxThresholdWallet.executeTransaction(0);

        // Add third confirmation
        vm.prank(owner3);
        maxThresholdWallet.confirmTransaction(0);

        // Now should succeed
        vm.prank(owner1);
        maxThresholdWallet.executeTransaction(0);

        (, , , bool executed, ) = maxThresholdWallet.transactions(0);
        assertTrue(executed);
    }
}

// Helper contract for testing failed transactions
contract RejectETH {
    // This contract rejects all ETH transfers
    receive() external payable {
        revert("ETH not accepted");
    }
}