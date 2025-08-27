// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title Vault
 * @author Reward Campaign System
 * @notice Individual campaign vault contract that manages token funding and reward distribution
 * @dev This contract is deployed as a minimal proxy clone by the Factory contract.
 *      Each vault represents a single reward campaign with one-time funding and distribution.
 *
 *      Key features:
 *      - Initializable proxy pattern for gas-efficient deployment
 *      - Single-use funding mechanism with automatic fee deduction
 *      - Batch reward distribution with campaign finalization
 *      - Emergency token rescue functionality
 *      - Comprehensive access control and validation
 *
 * @custom:security-contact security@rewardcampaign.com
 */
contract Vault is IVault, Initializable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    /// @notice Address of the Factory contract that deployed this vault
    /// @dev Used to validate token allowlist and retrieve fee configuration
    address public factoryAddress;

    /// @notice Address of the campaign creator who can fund this vault
    /// @dev Set during initialization and cannot be changed
    address public creator;

    /// @notice Address of the ERC20 token used for this campaign
    /// @dev Set during funding and determines the reward token type
    address public tokenAddress;

    /// @notice Whether the campaign has been finalized (rewards distributed)
    /// @dev Once true, no further operations are allowed except token rescue
    bool public isFinalized;

    /// @notice Whether the vault has been funded with initial tokens
    /// @dev Prevents multiple funding attempts and enables distribution
    bool public isFunded;

    /// @notice Amount of tokens available for distribution (net of fees)
    /// @dev Set during funding after fee deduction
    uint256 public fundAmount;

    /// @notice Address authorized to distribute rewards and rescue tokens
    /// @dev Set during initialization, typically managed by the Factory
    address public distributor;

    // --- Constructor ---

    /**
     * @notice Constructor that disables initializers for the implementation contract
     * @dev This prevents the implementation contract from being initialized directly.
     *      Only proxy clones can be initialized through the initialize() function.
     */
    constructor() {
        _disableInitializers();
    }

    // --- Modifiers ---

    /**
     * @notice Restricts function access to the authorized distributor only
     * @dev Used for reward distribution and token rescue operations
     */
    modifier onlyDistributor() {
        if (msg.sender != distributor) revert Errors.UnauthorizedDistributor();
        _;
    }

    // --- Initializer ---

    /**
     * @notice Initializes the vault with campaign-specific parameters
     * @dev Called once by the Factory immediately after proxy deployment.
     *      Uses OpenZeppelin's initializer modifier to prevent re-initialization.
     *
     * @param _factoryAddress Address of the Factory contract that deployed this vault
     * @param _distributor Address authorized to distribute rewards and rescue tokens
     * @param _creator Address of the campaign creator who can fund this vault
     *
     * Requirements:
     * - Can only be called once due to initializer modifier
     * - Factory address cannot be zero address
     * - Called automatically by Factory during campaign creation
     */
    function initialize(address _factoryAddress, address _distributor, address _creator) public initializer {
        if (_factoryAddress == address(0)) revert Errors.ZeroAddress();
        factoryAddress = _factoryAddress;
        distributor = _distributor;
        creator = _creator;
    }

    // --- View Functions ---

    /**
     * @notice Returns the current token balance held by this vault
     * @dev Queries the ERC20 token contract directly for real-time balance
     *
     * @return Current balance of the reward token in this vault
     *
     * Note: Returns 0 if the vault hasn't been funded yet (tokenAddress is zero)
     */
    function getBalance() public view override returns (uint256) {
        if (tokenAddress == address(0)) return 0;
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @notice Returns the initial funding amount (net of fees)
     * @dev This represents the amount available for distribution, not current balance
     *
     * @return The net funding amount after fee deduction
     */
    function getFundAmount() external view override returns (uint256) {
        return fundAmount;
    }

    /**
     * @notice Returns the address of the campaign creator
     * @dev The creator is the only address authorized to fund this vault
     *
     * @return Address of the campaign creator
     */
    function getCreator() external view override returns (address) {
        return creator;
    }

    /**
     * @notice Returns the address of the reward token used by this campaign
     * @dev Returns zero address if the vault hasn't been funded yet
     *
     * @return Address of the ERC20 token contract used for rewards
     */
    function getTokenAddress() external view override returns (address) {
        return tokenAddress;
    }

    /**
     * @notice Returns the address authorized to distribute rewards
     * @dev This address can distribute rewards and rescue tokens
     *
     * @return Address of the authorized distributor
     */
    function getDistributor() external view override returns (address) {
        return distributor;
    }

    // --- Core Functions ---

    /**
     * @notice Funds the vault with reward tokens for distribution
     * @dev This function can only be called once by the campaign creator.
     *      Automatically deducts platform fees and transfers them to the fee wallet.
     *
     * @param _tokenAddress Address of the ERC20 token to use for rewards
     * @param amount Total amount of tokens to transfer (including fees)
     *
     * Requirements:
     * - Token must be in the Factory's allowlist
     * - Vault must not already be funded
     * - Amount must be greater than zero
     * - Can only be called by the campaign creator
     * - Creator must have sufficient token balance and approval
     *
     * Effects:
     * - Sets the vault's token address
     * - Calculates and deducts platform fees
     * - Transfers net amount to vault and fees to fee wallet
     * - Marks vault as funded
     * - Emits VaultFunded event
     *
     * @custom:security This function includes automatic fee processing and cannot be called multiple times
     */
    function fund(address _tokenAddress, uint256 amount) external override {
        if (!IFactory(factoryAddress).isTokenAllowed(_tokenAddress)) revert Errors.TokenNotAllowed();
        if (isFunded) revert Errors.AlreadyFunded();
        if (amount == 0) revert Errors.InvalidAmount();
        if (msg.sender != creator) revert Errors.OnlyCreatorCanFund();

        uint8 feePercentage = IFactory(factoryAddress).getCampaignFeePercentage();
        address feeWallet = IFactory(factoryAddress).getFeeWallet();
        uint256 feeAmount = (amount * feePercentage) / 100;
        uint256 vaultAmount = amount - feeAmount;

        tokenAddress = _tokenAddress;
        fundAmount = vaultAmount;
        isFunded = true;

        IERC20(_tokenAddress).safeTransferFrom(creator, address(this), amount);
        if (feeAmount > 0 && feeWallet != address(0)) {
            IERC20(_tokenAddress).safeTransfer(feeWallet, feeAmount);
        }

        emit VaultFunded(creator, _tokenAddress, amount);
    }

    /**
     * @notice Distributes rewards to multiple recipients and finalizes the campaign
     * @dev This function can only be called once and permanently finalizes the campaign.
     *      All reward transfers are executed atomically - if any transfer fails, the entire transaction reverts.
     *
     * @param rewards Array of Reward structs containing recipient addresses and amounts
     *
     * Requirements:
     * - Can only be called by the authorized distributor
     * - Campaign must not already be finalized
     * - Rewards array cannot be empty
     * - All recipients must be valid (non-zero) addresses
     * - All reward amounts must be greater than zero
     * - Total reward amount cannot exceed vault balance
     * - Vault must be funded before distribution
     *
     * Effects:
     * - Validates all reward parameters before execution
     * - Transfers tokens to all recipients using SafeERC20
     * - Permanently finalizes the campaign (sets isFinalized to true)
     * - Emits RewardsDistributed event with full reward details
     *
     * @custom:security This function finalizes the campaign permanently and cannot be undone
     */
    function distributeRewards(Reward[] calldata rewards) external override onlyDistributor {
        if (isFinalized) revert Errors.CampaignFinalized();
        if (rewards.length == 0) revert Errors.ArrayLengthMismatch();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < rewards.length; i++) {
            if (rewards[i].recipient == address(0)) revert Errors.ZeroAddress();
            if (rewards[i].amount == 0) revert Errors.InvalidAmount();
            totalAmount += rewards[i].amount;
        }
        if (getBalance() < totalAmount) revert Errors.InsufficientFunds();

        isFinalized = true;

        for (uint256 i = 0; i < rewards.length; i++) {
            IERC20(tokenAddress).safeTransfer(rewards[i].recipient, rewards[i].amount);
        }

        emit RewardsDistributed(msg.sender, rewards, totalAmount);
    }

    /**
     * @notice Rescues tokens that were accidentally sent to this vault
     * @dev Emergency function to recover tokens that don't belong to the campaign.
     *      Can be used to rescue any ERC20 tokens, including the main reward token after distribution.
     *
     * @param recipient Address to receive the rescued tokens
     * @param _tokenAddress Address of the token contract to rescue from
     * @param amount Amount of tokens to rescue and transfer
     *
     * Requirements:
     * - Can only be called by the authorized distributor
     * - Recipient address cannot be zero
     * - Token contract must be valid and have sufficient balance
     * - Amount must be greater than zero
     *
     * Effects:
     * - Transfers specified amount of tokens to recipient using SafeERC20
     * - Emits TokenRescued event for transparency
     *
     * Use Cases:
     * - Recovering accidentally sent tokens
     * - Retrieving remaining tokens after campaign completion
     * - Emergency token recovery for operational purposes
     *
     * @custom:security This function should be used carefully and only for legitimate recovery purposes
     */
    function rescueToken(address recipient, address _tokenAddress, uint256 amount) external override onlyDistributor {
        IERC20(_tokenAddress).safeTransfer(recipient, amount);
        emit TokenRescued(msg.sender, recipient, _tokenAddress, amount);
    }
}
