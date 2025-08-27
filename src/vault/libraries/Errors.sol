// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @author Reward Campaign System
 * @notice Custom error definitions for the reward campaign system
 * @dev Centralized error library to ensure consistency across all contracts.
 *      Using custom errors instead of require strings saves gas and provides
 *      better error handling for frontend applications.
 */
library Errors {
    // --- Factory Errors ---

    /// @notice Thrown when a zero address is provided where a valid address is required
    error ZeroAddress();

    /// @notice Thrown when an invalid distributor address is provided
    error InvalidDistributor();

    /// @notice Thrown when an invalid vault implementation address is provided
    error InvalidClassHash();

    /// @notice Thrown when an invalid fee wallet address is provided
    error InvalidFeeWallet();

    /// @notice Thrown when fee percentage is greater than 100
    error InvalidFeePercentage();

    /// @notice Thrown when an invalid token address is provided for allowlist operations
    error InvalidTokenAddress();

    /// @notice Thrown when trying to access a vault that doesn't exist
    error VaultNotFound();

    // --- Vault Errors ---

    /// @notice Thrown when trying to fund a vault with a token not in the allowlist
    error TokenNotAllowed();

    /// @notice Thrown when trying to fund a vault that has already been funded
    error AlreadyFunded();

    /// @notice Thrown when an invalid amount (zero or negative) is provided
    error InvalidAmount();

    /// @notice Thrown when someone other than the creator tries to fund the vault
    error OnlyCreatorCanFund();

    /// @notice Thrown when a token transfer operation fails
    error TransferFailed();

    /// @notice Thrown when trying to perform operations on a finalized campaign
    error CampaignFinalized();

    /// @notice Thrown when array parameters have mismatched or invalid lengths
    error ArrayLengthMismatch();

    /// @notice Thrown when vault doesn't have sufficient funds for the requested operation
    error InsufficientFunds();

    /// @notice Thrown when someone other than the authorized distributor tries to distribute rewards
    error UnauthorizedDistributor();

    /// @notice Thrown when an unauthorized upgrade attempt is made
    error UnauthorizedUpgrade();
}
