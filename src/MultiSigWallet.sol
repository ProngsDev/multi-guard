//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    //errors
    error InvalidNumberOfOwners(uint256 numOwners);
    error InvalidThreshold(uint256 threshold);
    error ZeroAddress();
    error NotUnique(address owner);
    error NotOwner();
    error TxDoesNotExist(uint256 txIndex);
    error AlreadyExecuted();
    error AlreadyConfirmed();

    //events
    event TransactionSubmitted(uint256 txIndex, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 txIndex, address indexed owner);
    event TransactionExecuted(uint256 txIndex);

    //types
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    //states
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    //modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], NotOwner());
        _;
    }

    modifier txExists(uint256 txIndex) {
        require(txIndex < transactions.length, TxDoesNotExist(txIndex));
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        require(!transactions[txIndex].executed, AlreadyExecuted());
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        require(!confirmations[txIndex][msg.sender], AlreadyConfirmed());
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0 && _owners.length <= 10, InvalidNumberOfOwners(_owners.length));
        require(_threshold > 0 && _threshold <= _owners.length, InvalidThreshold(_threshold));
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), ZeroAddress());
            require(!isOwner[owner], NotUnique(owner));

            isOwner[owner] = true;
            owners.push(owner);
        }
        threshold = _threshold;
    }

    function submitTransaction(address to, uint256 value, bytes memory data) public onlyOwner {
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, numConfirmations: 0}));
        emit TransactionSubmitted(transactions.length - 1, to, value, data);
    }

    function confirmTransaction(uint256 txIndex)
        public
        onlyOwner
        txExists(txIndex)
        notExecuted(txIndex)
        notConfirmed(txIndex)
    {
        confirmations[txIndex][msg.sender] = true;
        transactions[txIndex].numConfirmations++;
        emit TransactionConfirmed(txIndex, msg.sender);
    }

    function executeTransaction(uint256 txIndex) public onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage txn = transactions[txIndex];
        require(txn.numConfirmations >= threshold, "Not enough confirmations");
        txn.executed = true;
        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");
        emit TransactionExecuted(txIndex);
    }

    receive() external payable {}
}
