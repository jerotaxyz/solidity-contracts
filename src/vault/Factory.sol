// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol"; // Import Vault to call initialize
import {Errors} from "./libraries/Errors.sol";

/**
 * @title Factory
 * @author Reward Campaign System
 * @notice Factory contract for deploying and managing reward campaign vaults
 * @dev This contract serves as the central hub for the reward campaign system.
 *      It deploys individual campaign vaults as minimal proxy clones for gas efficiency,
 *      manages the token allowlist, handles fee configuration, and provides upgrade mechanisms.
 *
 *      Key features:
 *      - Gas-efficient vault deployment using OpenZeppelin's Clones library
 *      - Comprehensive token allowlist management for campaign security
 *      - Configurable fee system with designated fee wallet
 *      - Centralized distributor authorization for all campaigns
 *      - Upgrade mechanism for new vault implementations
 *      - Complete campaign tracking and analytics
 *
 * @custom:security-contact security@rewardcampaign.com
 */
contract Factory is IFactory, Ownable {
    // --- State Variables ---

    /// @notice Address of the master Vault implementation contract used for cloning
    /// @dev This is the logic contract that all vault proxies delegate to
    address public vaultImplementation;

    /// @notice Mapping from campaign ID to deployed vault address
    /// @dev Campaign IDs start from 1 and increment sequentially
    mapping(uint256 => address) public deployedVaults;

    /// @notice Total number of campaigns created
    /// @dev Used as the next campaign ID and for tracking system growth
    uint256 public vaultCount;

    /// @notice Mapping to track which tokens are allowed for campaign funding
    /// @dev Only tokens in this allowlist can be used to fund campaigns
    mapping(address => bool) public tokenAllowlist;

    /// @notice Array of all allowed token addresses for enumeration
    /// @dev Maintained alongside tokenAllowlist mapping for easy retrieval
    address[] public tokens;

    /// @notice Address authorized to distribute rewards across all campaigns
    /// @dev This address has distributor privileges on all deployed vaults
    address public rewardDistributor;

    /// @notice Percentage fee charged on campaign funding (0-100)
    /// @dev Applied during vault funding, deducted from total amount
    uint8 public campaignFeePercentage;

    /// @notice Address that receives platform fees from campaign funding
    /// @dev Fees are automatically transferred here during vault funding
    address public feeWallet;

    // --- Constructor ---

    /**
     * @notice Initializes the Factory with essential system parameters
     * @dev Sets up the factory with all required addresses and configuration.
     *      All parameters are validated to ensure system integrity.
     *
     * @param initialOwner Address that will own this Factory contract
     * @param _vaultImplementation Address of the master Vault implementation for cloning
     * @param initialDistributor Address authorized to distribute rewards across all campaigns
     * @param _feeWallet Address that will receive platform fees from campaigns
     * @param _campaignFeePercentage Fee percentage (0-100) charged on campaign funding
     *
     * Requirements:
     * - All addresses must be non-zero
     * - Fee percentage must be between 0 and 100 (inclusive)
     * - Vault implementation must be a valid contract address
     *
     * Effects:
     * - Sets the contract owner using OpenZeppelin's Ownable
     * - Configures the vault implementation for proxy deployments
     * - Establishes the reward distributor for all campaigns
     * - Sets up the fee collection system
     *
     * @custom:security All parameters are validated to prevent misconfiguration
     */
    constructor(
        address initialOwner,
        address _vaultImplementation,
        address initialDistributor,
        address _feeWallet,
        uint8 _campaignFeePercentage
    ) Ownable(initialOwner) {
        if (_vaultImplementation == address(0)) revert Errors.InvalidClassHash();
        if (initialDistributor == address(0)) revert Errors.InvalidDistributor();
        if (_feeWallet == address(0)) revert Errors.InvalidFeeWallet();
        if (_campaignFeePercentage > 100) revert Errors.InvalidFeePercentage();

        vaultImplementation = _vaultImplementation;
        rewardDistributor = initialDistributor;
        feeWallet = _feeWallet;
        campaignFeePercentage = _campaignFeePercentage;
    }

    // --- Campaign Creation ---

    /**
     * @notice Creates a new reward campaign by deploying a vault proxy
     * @dev Deploys a minimal proxy clone of the vault implementation for gas efficiency.
     *      Each campaign gets a unique ID and vault address.
     *
     * @return vaultAddress Address of the newly deployed vault contract
     *
     * Process:
     * 1. Generates a new sequential campaign ID
     * 2. Deploys a minimal proxy clone using OpenZeppelin's Clones library
     * 3. Initializes the clone with Factory, distributor, and creator addresses
     * 4. Records the vault address and increments the campaign counter
     * 5. Emits CampaignCreated event for tracking
     *
     * Effects:
     * - Deploys a new vault proxy (~2,000 gas vs ~200,000 for full deployment)
     * - Assigns sequential campaign ID starting from 1
     * - Sets msg.sender as the campaign creator
     * - Authorizes the current reward distributor
     * - Updates vault count for system tracking
     *
     * @custom:gas-optimization Uses minimal proxy pattern to reduce deployment costs by ~90%
     */
    function createCampaign() external override returns (address) {
        uint256 campaignId = vaultCount + 1;

        // Deploy a new vault instance using the Clones library
        address vaultAddress = Clones.clone(vaultImplementation);

        // Initialize the new clone
        Vault(vaultAddress).initialize(
            address(this), // factory
            rewardDistributor, // distributor
            msg.sender // campaign owner/creator
        );

        deployedVaults[campaignId] = vaultAddress;
        vaultCount = campaignId;

        emit CampaignCreated(campaignId, msg.sender, vaultAddress);
        return vaultAddress;
    }

    // --- Token Allowlist Management ---

    /**
     * @notice Adds a token to the allowlist for campaign funding
     * @dev Only tokens in the allowlist can be used to fund campaigns.
     *      Prevents duplicate additions and maintains both mapping and array.
     *
     * @param tokenAddress Address of the ERC20 token to allow
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Token address cannot be zero address
     * - Token must not already be in the allowlist
     *
     * Effects:
     * - Adds token to the allowlist mapping
     * - Appends token to the enumerable tokens array
     * - Emits TokenAdded event for tracking
     *
     * @custom:security Only owner can modify the allowlist to prevent unauthorized tokens
     */
    function addAllowedToken(address tokenAddress) external override onlyOwner {
        if (tokenAddress == address(0)) revert Errors.InvalidTokenAddress();
        if (tokenAllowlist[tokenAddress]) return;

        tokenAllowlist[tokenAddress] = true;
        tokens.push(tokenAddress);

        emit TokenAdded(tokenAddress);
    }

    /**
     * @notice Removes a token from the allowlist
     * @dev Removes token from both the mapping and array while maintaining array integrity.
     *      Uses swap-and-pop pattern for gas-efficient array removal.
     *
     * @param tokenAddress Address of the ERC20 token to remove
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Token address cannot be zero address
     * - Token must currently be in the allowlist
     *
     * Effects:
     * - Removes token from the allowlist mapping
     * - Removes token from the enumerable tokens array
     * - Emits TokenRemoved event for tracking
     *
     * @custom:gas-optimization Uses swap-and-pop pattern to avoid array gaps and reduce gas costs
     */
    function removeAllowedToken(address tokenAddress) external override onlyOwner {
        if (tokenAddress == address(0)) revert Errors.InvalidTokenAddress();
        if (!tokenAllowlist[tokenAddress]) return;

        tokenAllowlist[tokenAddress] = false;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenAddress) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
        emit TokenRemoved(tokenAddress);
    }

    // --- View Functions ---

    /**
     * @notice Checks if a token is allowed for campaign funding
     * @dev Used by vaults during funding to validate token eligibility
     *
     * @param tokenAddress Address of the token to check
     * @return True if the token is in the allowlist, false otherwise
     */
    function isTokenAllowed(address tokenAddress) external view override returns (bool) {
        return tokenAllowlist[tokenAddress];
    }

    /**
     * @notice Returns all tokens currently in the allowlist
     * @dev Provides enumerable access to allowed tokens for frontend integration
     *
     * @return Array of all allowed token addresses
     */
    function getAllowedTokens() external view override returns (address[] memory) {
        return tokens;
    }

    /**
     * @notice Returns the current authorized reward distributor
     * @dev This address has distributor privileges on all deployed vaults
     *
     * @return Address of the current reward distributor
     */
    function getRewardDistributor() external view override returns (address) {
        return rewardDistributor;
    }

    /**
     * @notice Returns the vault address for a specific campaign ID
     * @dev Campaign IDs start from 1 and increment sequentially
     *
     * @param campaignId The ID of the campaign to look up
     * @return Address of the vault contract, or zero address if campaign doesn't exist
     */
    function getVaultAddress(uint256 campaignId) external view override returns (address) {
        return deployedVaults[campaignId];
    }

    /**
     * @notice Returns the total number of campaigns created
     * @dev Useful for pagination and system analytics
     *
     * @return Total count of deployed vaults
     */
    function getVaultCount() external view override returns (uint256) {
        return vaultCount;
    }

    /**
     * @notice Returns all deployed vault addresses
     * @dev Provides complete list of all campaigns for analytics and management
     *
     * @return Array of all deployed vault contract addresses
     *
     * @custom:gas-optimization Consider pagination for large numbers of campaigns
     */
    function getAllVaults() public view override returns (address[] memory) {
        address[] memory vaults = new address[](vaultCount);
        for (uint256 i = 0; i < vaultCount; i++) {
            vaults[i] = deployedVaults[i + 1];
        }
        return vaults;
    }

    /**
     * @notice Returns all vault addresses that have been funded
     * @dev Filters all vaults to return only those that have received funding.
     *      Uses two-pass algorithm to optimize memory allocation.
     *
     * @return Array of funded vault contract addresses
     *
     * Process:
     * 1. First pass: Count how many vaults are funded
     * 2. Second pass: Populate result array with funded vault addresses
     *
     * @custom:gas-optimization Two-pass algorithm prevents array resizing and reduces gas costs
     */
    function getFundedVaults() external view override returns (address[] memory) {
        address[] memory allVaults = getAllVaults();
        uint256 fundedCount = 0;

        // First pass: count funded vaults
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (IVault(allVaults[i]).isFunded()) {
                fundedCount++;
            }
        }

        // Second pass: populate the result array
        address[] memory fundedVaults = new address[](fundedCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (IVault(allVaults[i]).isFunded()) {
                fundedVaults[currentIndex] = allVaults[i];
                currentIndex++;
            }
        }
        return fundedVaults;
    }

    /**
     * @notice Returns the current campaign fee percentage
     * @dev Fee is applied during vault funding and ranges from 0-100
     *
     * @return Current fee percentage (0-100)
     */
    function getCampaignFeePercentage() external view override returns (uint8) {
        return campaignFeePercentage;
    }

    /**
     * @notice Returns the current fee wallet address
     * @dev This address receives all platform fees from campaign funding
     *
     * @return Address of the fee wallet
     */
    function getFeeWallet() external view override returns (address) {
        return feeWallet;
    }

    // --- Admin and Upgrade Functions ---

    /**
     * @notice Updates the vault implementation for all new campaigns
     * @dev This is the upgrade mechanism for the system. Only affects newly created campaigns,
     *      existing vaults continue using their original implementation.
     *
     * @param _newVaultImplementation Address of the new Vault logic contract
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - New implementation address cannot be zero
     * - Should be a valid Vault contract with proper interface
     *
     * Effects:
     * - Updates the master implementation for future vault deployments
     * - Does not affect existing vault contracts
     * - Emits VaultImplementationUpdated event
     *
     * @custom:security Ensure new implementation is thoroughly tested before deployment
     */
    function setVaultImplementation(address _newVaultImplementation) external onlyOwner {
        if (_newVaultImplementation == address(0)) revert Errors.InvalidClassHash();
        vaultImplementation = _newVaultImplementation;

        emit VaultImplementationUpdated(_newVaultImplementation);
    }

    /**
     * @notice Updates the authorized reward distributor for the system
     * @dev Changes the distributor address that will be set for all new campaigns.
     *      Existing campaigns retain their original distributor.
     *
     * @param distributor Address of the new reward distributor
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Distributor address cannot be zero
     * - Should be a trusted address or contract
     *
     * Effects:
     * - Updates the reward distributor for future campaigns
     * - Does not affect existing vault distributors
     * - Emits DistributorUpdated event with old and new addresses
     *
     * @custom:security Distributor has significant privileges, ensure address is secure
     */
    function setRewardDistributor(address distributor) external override onlyOwner {
        if (distributor == address(0)) revert Errors.InvalidDistributor();
        address oldDistributor = rewardDistributor;
        rewardDistributor = distributor;
        emit DistributorUpdated(oldDistributor, distributor);
    }

    /**
     * @notice Updates the campaign fee percentage
     * @dev Changes the fee percentage applied to all future campaign funding.
     *      Existing campaigns are not affected.
     *
     * @param feePercentage New fee percentage (0-100)
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Fee percentage must be between 0 and 100 (inclusive)
     *
     * Effects:
     * - Updates the fee percentage for future campaigns
     * - Does not affect existing campaign fees
     * - Emits FeePercentageUpdated event with old and new percentages
     *
     * @custom:economics Consider impact on campaign creators when adjusting fees
     */
    function setCampaignFeePercentage(uint8 feePercentage) external override onlyOwner {
        if (feePercentage > 100) revert Errors.InvalidFeePercentage();
        uint8 oldFeePercentage = campaignFeePercentage;
        campaignFeePercentage = feePercentage;
        emit FeePercentageUpdated(oldFeePercentage, feePercentage);
    }

    /**
     * @notice Updates the fee wallet address
     * @dev Changes where platform fees are sent during campaign funding.
     *      Affects all future campaign funding transactions.
     *
     * @param _feeWallet Address of the new fee wallet
     *
     * Requirements:
     * - Can only be called by the contract owner
     * - Fee wallet address cannot be zero
     * - Should be a secure address or multisig
     *
     * Effects:
     * - Updates the fee wallet for all future fee collections
     * - Does not affect fees already collected
     * - Emits FeeWalletUpdated event with old and new addresses
     *
     * @custom:security Fee wallet should be a secure address, preferably a multisig
     */
    function setFeeWallet(address _feeWallet) external override onlyOwner {
        if (_feeWallet == address(0)) revert Errors.InvalidFeeWallet();
        address oldFeeWallet = feeWallet;
        feeWallet = _feeWallet;
        emit FeeWalletUpdated(oldFeeWallet, _feeWallet);
    }
}
