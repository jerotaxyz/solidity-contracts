// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Vault Events
 * @author Reward Campaign System
 * @notice Event definitions and data structures for Vault contracts
 * @dev These events provide comprehensive tracking of vault operations
 *      for analytics, monitoring, and frontend integration.
 */

/**
 * @notice Structure defining a single reward distribution
 * @param recipient Address that will receive the reward tokens
 * @param amount Number of tokens to be distributed to the recipient
 */
struct Reward {
    address recipient;
    uint256 amount;
}

/**
 * @notice Emitted when a vault is successfully funded by its creator
 * @param creator Address of the campaign creator who funded the vault
 * @param tokenAddress Address of the ERC20 token used for funding
 * @param amount Total amount of tokens transferred (including fees)
 */
event VaultFunded(address indexed creator, address indexed tokenAddress, uint256 amount);

/**
 * @notice Emitted when rewards are distributed and the campaign is finalized
 * @param distributor Address of the distributor who executed the distribution
 * @param rewards Array of all reward distributions made
 * @param totalAmount Total amount of tokens distributed across all recipients
 */
event RewardsDistributed(address indexed distributor, Reward[] rewards, uint256 totalAmount);

/**
 * @notice Emitted when tokens are rescued from the vault
 * @param distributor Address of the distributor who executed the rescue
 * @param recipient Address that received the rescued tokens
 * @param tokenAddress Address of the token contract that was rescued
 * @param amount Amount of tokens that were rescued
 */
event TokenRescued(
    address indexed distributor, address indexed recipient, address indexed tokenAddress, uint256 amount
);
