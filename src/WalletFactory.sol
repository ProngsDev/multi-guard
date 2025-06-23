//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MultiSigWallet} from "./MultiSigWallet.sol";

/**
 * @title WalletFactory
 * @author Multi-Guard Team
 * @notice Factory contract for deploying MultiSigWallet instances using CREATE2
 * @dev Uses CREATE2 opcode for deterministic address generation
 */
contract WalletFactory {
    // ============ Custom Errors ============

    /// @notice Thrown when owners array is empty or exceeds maximum allowed
    error InvalidOwnersLength(uint256 length);

    /// @notice Thrown when threshold is invalid (0 or greater than owners length)
    error InvalidThreshold(uint256 threshold, uint256 ownersLength);

    /// @notice Thrown when an owner address is zero
    error ZeroAddressOwner();

    /// @notice Thrown when duplicate owners are provided
    error DuplicateOwner(address owner);

    /// @notice Thrown when wallet deployment fails
    error WalletDeploymentFailed();

    /// @notice Thrown when trying to predict address with invalid parameters
    error InvalidPredictionParameters();

    // ============ Events ============

    /// @notice Emitted when a new wallet is successfully created
    /// @param creator Address that created the wallet
    /// @param wallet Address of the deployed wallet
    /// @param owners Array of wallet owners
    /// @param threshold Required number of confirmations
    /// @param salt Salt used for CREATE2 deployment
    event WalletCreated(
        address indexed creator, address indexed wallet, address[] owners, uint256 threshold, bytes32 salt
    );

    /// @notice Emitted when a wallet address is predicted (optional for UX)
    /// @param creator Address that will create the wallet
    /// @param predictedAddress Predicted wallet address
    /// @param salt Salt that will be used for deployment
    event WalletAddressPredicted(address indexed creator, address indexed predictedAddress, bytes32 salt);

    // ============ State Variables ============

    /// @notice Mapping from creator address to array of their created wallets
    mapping(address => address[]) public walletsByCreator;

    /// @notice Mapping to check if a wallet was created by this factory
    mapping(address => bool) public isFactoryWallet;

    /// @notice Counter for generating unique salts per creator
    mapping(address => uint256) public creatorNonce;

    /// @notice Total number of wallets created by this factory
    uint256 public totalWalletsCreated;

    // ============ Constants ============

    /// @notice Maximum number of owners allowed per wallet
    uint256 public constant MAX_OWNERS = 10;

    /// @notice Minimum number of owners required per wallet
    uint256 public constant MIN_OWNERS = 1;

    // ============ Main Functions ============

    /**
     * @notice Creates a new MultiSigWallet using CREATE2 for deterministic addresses
     * @param owners Array of wallet owner addresses
     * @param threshold Number of required confirmations for transactions
     * @return walletAddress Address of the deployed wallet
     */
    function createWallet(address[] memory owners, uint256 threshold) external returns (address walletAddress) {
        // Validate input parameters
        _validateWalletParameters(owners, threshold);

        // Generate salt for CREATE2
        bytes32 salt = _generateSalt(msg.sender);

        // Deploy wallet using CREATE2
        walletAddress = _deployWallet(owners, threshold, salt);

        // Update registry
        _updateRegistry(msg.sender, walletAddress);

        // Emit event
        emit WalletCreated(msg.sender, walletAddress, owners, threshold, salt);

        return walletAddress;
    }

    /**
     * @notice Predicts the address of a wallet before deployment
     * @param creator Address that will create the wallet
     * @param owners Array of wallet owner addresses (for validation)
     * @param threshold Number of required confirmations (for validation)
     * @return predictedAddress The predicted wallet address
     * @return salt The salt that will be used for deployment
     */
    function predictWalletAddress(address creator, address[] memory owners, uint256 threshold)
        external
        view
        returns (address predictedAddress, bytes32 salt)
    {
        // Validate parameters
        if (creator == address(0)) revert InvalidPredictionParameters();
        _validateWalletParameters(owners, threshold);

        // Generate salt
        salt = _generateSaltForCreator(creator);

        // Calculate predicted address
        predictedAddress = _calculateWalletAddress(owners, threshold, salt);

        return (predictedAddress, salt);
    }

    /**
     * @notice Gets all wallets created by a specific address
     * @param creator Address to query wallets for
     * @return wallets Array of wallet addresses created by the creator
     */
    function getWalletsByCreator(address creator) external view returns (address[] memory wallets) {
        return walletsByCreator[creator];
    }

    /**
     * @notice Gets the number of wallets created by a specific address
     * @param creator Address to query wallet count for
     * @return count Number of wallets created by the creator
     */
    function getWalletCountByCreator(address creator) external view returns (uint256 count) {
        return walletsByCreator[creator].length;
    }

    /**
     * @notice Checks if a wallet address was created by this factory
     * @param wallet Address to check
     * @return isFactory True if wallet was created by this factory
     */
    function isWalletFromFactory(address wallet) external view returns (bool isFactory) {
        return isFactoryWallet[wallet];
    }

    // ============ Internal Functions ============

    /**
     * @notice Validates wallet creation parameters
     * @param owners Array of owner addresses
     * @param threshold Required number of confirmations
     */
    function _validateWalletParameters(address[] memory owners, uint256 threshold) internal pure {
        // Check owners array length
        if (owners.length < MIN_OWNERS || owners.length > MAX_OWNERS) {
            revert InvalidOwnersLength(owners.length);
        }

        // Check threshold validity
        if (threshold == 0 || threshold > owners.length) {
            revert InvalidThreshold(threshold, owners.length);
        }

        // Check for zero addresses and duplicates
        for (uint256 i = 0; i < owners.length;) {
            if (owners[i] == address(0)) {
                revert ZeroAddressOwner();
            }

            // Check for duplicates
            for (uint256 j = i + 1; j < owners.length;) {
                if (owners[i] == owners[j]) {
                    revert DuplicateOwner(owners[i]);
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Generates a unique salt for CREATE2 deployment
     * @param creator Address creating the wallet
     * @return salt Generated salt
     */
    function _generateSalt(address creator) internal returns (bytes32 salt) {
        uint256 nonce = creatorNonce[creator]++;
        salt = keccak256(abi.encodePacked(creator, nonce, block.timestamp));
        return salt;
    }

    /**
     * @notice Generates a salt for a specific creator (view function)
     * @param creator Address that will create the wallet
     * @return salt Generated salt
     */
    function _generateSaltForCreator(address creator) internal view returns (bytes32 salt) {
        uint256 nonce = creatorNonce[creator];
        salt = keccak256(abi.encodePacked(creator, nonce, block.timestamp));
        return salt;
    }

    /**
     * @notice Deploys a wallet using CREATE2
     * @param owners Array of owner addresses
     * @param threshold Required number of confirmations
     * @param salt Salt for CREATE2 deployment
     * @return walletAddress Address of deployed wallet
     */
    function _deployWallet(address[] memory owners, uint256 threshold, bytes32 salt)
        internal
        returns (address walletAddress)
    {
        bytes memory bytecode = abi.encodePacked(type(MultiSigWallet).creationCode, abi.encode(owners, threshold));

        assembly {
            walletAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (walletAddress == address(0)) {
            revert WalletDeploymentFailed();
        }

        return walletAddress;
    }

    /**
     * @notice Calculates the wallet address that would be deployed with given parameters
     * @param owners Array of owner addresses
     * @param threshold Required number of confirmations
     * @param salt Salt for CREATE2 deployment
     * @return walletAddress Calculated wallet address
     */
    function _calculateWalletAddress(address[] memory owners, uint256 threshold, bytes32 salt)
        internal
        view
        returns (address walletAddress)
    {
        bytes memory bytecode = abi.encodePacked(type(MultiSigWallet).creationCode, abi.encode(owners, threshold));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Updates the wallet registry after successful deployment
     * @param creator Address that created the wallet
     * @param walletAddress Address of the deployed wallet
     */
    function _updateRegistry(address creator, address walletAddress) internal {
        walletsByCreator[creator].push(walletAddress);
        isFactoryWallet[walletAddress] = true;
        totalWalletsCreated++;
    }
}
