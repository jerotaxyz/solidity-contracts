// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Vault} from "./Vault.sol"; // Import Vault to call initialize
import {Errors} from "./libraries/Errors.sol";

contract Factory is IFactory, Ownable {
    // --- State Variables ---
    address public vaultImplementation;
    mapping(uint256 => address) public deployedVaults;
    uint256 public vaultCount;
    mapping(address => bool) public tokenAllowlist;
    address[] public tokens;
    address public rewardDistributor;
    uint8 public campaignFeePercentage;
    address public feeWallet;

    // --- Constructor ---
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
    function addAllowedToken(address tokenAddress) external override onlyOwner {
        if (tokenAddress == address(0)) revert Errors.InvalidTokenAddress();
        if (tokenAllowlist[tokenAddress]) return;

        tokenAllowlist[tokenAddress] = true;
        tokens.push(tokenAddress);

        emit TokenAdded(tokenAddress);
    }

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
    function isTokenAllowed(address tokenAddress) external view override returns (bool) {
        return tokenAllowlist[tokenAddress];
    }

    function getAllowedTokens() external view override returns (address[] memory) {
        return tokens;
    }

    function getRewardDistributor() external view override returns (address) {
        return rewardDistributor;
    }

    function getVaultAddress(uint256 campaignId) external view override returns (address) {
        return deployedVaults[campaignId];
    }

    function getVaultCount() external view override returns (uint256) {
        return vaultCount;
    }

    function getAllVaults() public view override returns (address[] memory) {
        address[] memory vaults = new address[](vaultCount);
        for (uint256 i = 0; i < vaultCount; i++) {
            vaults[i] = deployedVaults[i + 1];
        }
        return vaults;
    }

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

    function getCampaignFeePercentage() external view override returns (uint8) {
        return campaignFeePercentage;
    }

    function getFeeWallet() external view override returns (address) {
        return feeWallet;
    }

    // --- Admin and Upgrade Functions ---

    /**
     * @notice Sets the implementation address for all new vaults.
     * @dev This is the new upgrade mechanism. It does not affect existing vaults.
     * @param _newVaultImplementation The address of the new Vault logic contract.
     */
    function setVaultImplementation(address _newVaultImplementation) external onlyOwner {
        if (_newVaultImplementation == address(0)) revert Errors.InvalidClassHash();
        vaultImplementation = _newVaultImplementation;

        emit VaultImplementationUpdated(_newVaultImplementation);
    }

    function setRewardDistributor(address distributor) external override onlyOwner {
        if (distributor == address(0)) revert Errors.InvalidDistributor();
        address oldDistributor = rewardDistributor;
        rewardDistributor = distributor;
        emit DistributorUpdated(oldDistributor, distributor);
    }

    function setCampaignFeePercentage(uint8 feePercentage) external override onlyOwner {
        if (feePercentage > 100) revert Errors.InvalidFeePercentage();
        uint8 oldFeePercentage = campaignFeePercentage;
        campaignFeePercentage = feePercentage;
        emit FeePercentageUpdated(oldFeePercentage, feePercentage);
    }

    function setFeeWallet(address _feeWallet) external override onlyOwner {
        if (_feeWallet == address(0)) revert Errors.InvalidFeeWallet();
        address oldFeeWallet = feeWallet;
        feeWallet = _feeWallet;
        emit FeeWalletUpdated(oldFeeWallet, _feeWallet);
    }
}
