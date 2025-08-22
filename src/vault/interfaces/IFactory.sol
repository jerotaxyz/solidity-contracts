// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFactory
 * @notice Interface for the Factory contract, which deploys and manages reward campaign vaults.
 */
interface IFactory {
    // --- Events ---

    /**
     * @dev Emitted when a new campaign vault is created.
     */
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, address vaultAddress);

    /**
     * @dev Emitted when a new token is added to the allowlist.
     */
    event TokenAdded(address indexed tokenAddress);

    /**
     * @dev Emitted when a token is removed from the allowlist.
     */
    event TokenRemoved(address indexed tokenAddress);

    /**
     * @dev Emitted when the reward distributor address is updated.
     */
    event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);

    /**
     * @dev Emitted when the campaign fee percentage is changed.
     */
    event FeePercentageUpdated(uint8 oldFeePercentage, uint8 newFeePercentage);

    /**
     * @dev Emitted when the fee wallet address is updated.
     */
    event FeeWalletUpdated(address indexed oldFeeWallet, address indexed newFeeWallet);

    /**
     * @dev Emitted when the master implementation for new vaults is updated.
     */
    event VaultImplementationUpdated(address indexed newVaultImplementation);

    // --- Campaign Management ---

    /**
     * @notice Creates a new campaign vault as a minimal proxy clone.
     * @return vaultAddress The address of the newly created vault.
     */
    function createCampaign() external returns (address vaultAddress);

    // --- Token Allowlist Management ---

    /**
     * @notice Adds a token to the allowlist for funding campaigns.
     * @param tokenAddress Address of the token to add.
     */
    function addAllowedToken(address tokenAddress) external;

    /**
     * @notice Removes a token from the allowlist.
     * @param tokenAddress Address of the token to remove.
     */
    function removeAllowedToken(address tokenAddress) external;

    // --- View Functions ---

    /**
     * @notice Checks if a token is allowed for campaign creation.
     * @param tokenAddress Address of the token to check.
     * @return True if the token is allowed, false otherwise.
     */
    function isTokenAllowed(address tokenAddress) external view returns (bool);

    /**
     * @notice Gets all tokens currently in the allowlist.
     * @return An array of allowed token addresses.
     */
    function getAllowedTokens() external view returns (address[] memory);

    /**
     * @notice Gets the current authorized reward distributor.
     * @return The address of the current reward distributor.
     */
    function getRewardDistributor() external view returns (address);

    /**
     * @notice Gets the vault address for a specific campaign ID.
     * @param campaignId The ID of the campaign.
     * @return The address of the vault contract.
     */
    function getVaultAddress(uint256 campaignId) external view returns (address);

    /**
     * @notice Gets the total number of campaigns created.
     * @return The total count of vaults created.
     */
    function getVaultCount() external view returns (uint256);

    /**
     * @notice Gets all deployed vault addresses.
     * @return An array of all vault contract addresses.
     */
    function getAllVaults() external view returns (address[] memory);

    /**
     * @notice Gets all funded vault addresses.
     * @return An array of vault addresses that have been funded.
     */
    function getFundedVaults() external view returns (address[] memory);

    /**
     * @notice Gets the current campaign fee percentage.
     * @return The current fee percentage.
     */
    function getCampaignFeePercentage() external view returns (uint8);

    /**
     * @notice Gets the current fee wallet address.
     * @return The address of the fee wallet.
     */
    function getFeeWallet() external view returns (address);

    // --- Admin and Upgrade Functions ---

    /**
     * @notice Sets the master implementation address for all new vaults.
     * @dev This is the upgrade mechanism for new campaigns. It does not affect existing vaults.
     * @param newVaultImplementation The address of the new Vault logic contract.
     */
    function setVaultImplementation(address newVaultImplementation) external;

    /**
     * @notice Sets the authorized reward distributor for all vaults.
     * @param distributor Address of the new reward distributor.
     */
    function setRewardDistributor(address distributor) external;

    /**
     * @notice Sets the campaign fee percentage.
     * @param feePercentage The new fee percentage (0-100).
     */
    function setCampaignFeePercentage(uint8 feePercentage) external;

    /**
     * @notice Sets the fee wallet address.
     * @param feeWallet Address to receive campaign fees.
     */
    function setFeeWallet(address feeWallet) external;
}
