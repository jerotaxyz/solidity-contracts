// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Factory Events
 * @author Reward Campaign System
 * @notice Event definitions for the Factory contract
 * @dev These events provide comprehensive tracking of factory operations
 *      for analytics, monitoring, and frontend integration.
 */

/**
 * @notice Emitted when a new campaign vault is created
 * @param campaignId Unique sequential ID assigned to the campaign
 * @param creator Address of the user who created the campaign
 * @param vaultAddress Address of the newly deployed vault contract
 */
event CampaignCreated(uint256 indexed campaignId, address indexed creator, address vaultAddress);

/**
 * @notice Emitted when a token is added to the allowlist
 * @param tokenAddress Address of the token that was added
 */
event TokenAdded(address indexed tokenAddress);

/**
 * @notice Emitted when a token is removed from the allowlist
 * @param tokenAddress Address of the token that was removed
 */
event TokenRemoved(address indexed tokenAddress);

/**
 * @notice Emitted when the reward distributor address is updated
 * @param oldDistributor Previous distributor address
 * @param newDistributor New distributor address
 */
event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);

/**
 * @notice Emitted when the campaign fee percentage is changed
 * @param oldFeePercentage Previous fee percentage
 * @param newFeePercentage New fee percentage
 */
event FeePercentageUpdated(uint8 oldFeePercentage, uint8 newFeePercentage);

/**
 * @notice Emitted when the fee wallet address is updated
 * @param oldFeeWallet Previous fee wallet address
 * @param newFeeWallet New fee wallet address
 */
event FeeWalletUpdated(address indexed oldFeeWallet, address indexed newFeeWallet);

/**
 * @notice Emitted when the vault implementation is updated
 * @param newVaultImplementation Address of the new vault implementation
 */
event VaultImplementationUpdated(address indexed newVaultImplementation);
