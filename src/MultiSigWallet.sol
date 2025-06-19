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
        require(transactions[txIndex].numConfirmations < threshold, AlreadyConfirmed());
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

    function submitTransaction() public onlyOwner {}

    function confirmTransaction(uint256 txIndex)
        public
        onlyOwner
        txExists(txIndex)
        notExecuted(txIndex)
        notConfirmed(txIndex)
    {}

    function executeTransaction(uint256 txIndex) public onlyOwner txExists(txIndex) notExecuted(txIndex) {}

    receive() external payable {}
}
