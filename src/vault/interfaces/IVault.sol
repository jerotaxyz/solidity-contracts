// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @notice Interface for individual Campaign Vault contracts.
 * @dev Manages campaign-specific funds and the reward distribution process.
 * Each vault is deployed as a minimal proxy clone by the Factory.
 */
interface IVault {
    /**
     * @dev Defines the structure for a single reward distribution.
     * @param recipient The address that will receive the reward.
     * @param amount The quantity of tokens to be sent.
     */
    struct Reward {
        address recipient;
        uint256 amount;
    }

    // --- Events ---

    /**
     * @dev Emitted when a vault is successfully funded by its creator.
     */
    event VaultFunded(address indexed creator, address indexed tokenAddress, uint256 amount);

    /**
     * @dev Emitted when rewards are distributed and the campaign is finalized.
     */
    event RewardsDistributed(address indexed distributor, Reward[] rewards, uint256 totalAmount);

    /**
     * @dev Emitted when tokens (other than the main reward token) are rescued from the vault.
     */
    event TokenRescued(
        address indexed distributor, address indexed recipient, address indexed tokenAddress, uint256 amount
    );

    // --- View Functions ---

    /**
     * @notice Gets the current balance of the main reward token held by the vault.
     * @return The current ERC20 token balance.
     */
    function getBalance() external view returns (uint256);

    /**
     * @notice Gets the initial funding amount for this campaign (net of fees).
     * @return The initial funding amount.
     */
    function getFundAmount() external view returns (uint256);

    /**
     * @notice Gets the address of the campaign creator.
     * @return The address of the campaign creator.
     */
    function getCreator() external view returns (address);

    /**
     * @notice Gets the ERC20 token address used by this vault for rewards.
     * @return The address of the ERC20 token contract.
     */
    function getTokenAddress() external view returns (address);

    /**
     * @notice Checks if the reward distribution has occurred and the campaign is finalized.
     * @return True if the campaign is finalized, false otherwise.
     */
    function isFinalized() external view returns (bool);

    /**
     * @notice Checks if the vault has been funded with its initial tokens.
     * @return True if the vault is funded, false otherwise.
     */
    function isFunded() external view returns (bool);

    /**
     * @notice Gets the authorized reward distributor address.
     * @return The address authorized to distribute rewards.
     */
    function getDistributor() external view returns (address);

    // --- State-Changing Functions ---

    /**
     * @notice Initializes the vault's state variables.
     * @dev This function is called once by the Factory immediately after the vault clone is created.
     * @param factory The address of the Factory contract.
     * @param distributor The address of the authorized reward distributor.
     * @param creator The address of the campaign creator.
     */
    function initialize(address factory, address distributor, address creator) external;

    /**
     * @notice Funds the vault with the initial reward tokens.
     * @dev This can only be called by the campaign creator.
     * @param tokenAddress Address of the ERC20 token to fund with.
     * @param amount The total amount of tokens to transfer to the vault (inclusive of fees).
     */
    function fund(address tokenAddress, uint256 amount) external;

    /**
     * @notice Distributes rewards to the specified recipients and finalizes the campaign.
     * @dev Can only be called by the authorized distributor.
     * @param rewards An array of Reward structs, each containing a recipient and an amount.
     */
    function distributeRewards(Reward[] calldata rewards) external;

    /**
     * @notice Rescues tokens that were mistakenly sent to the vault.
     * @dev Can only be called by the authorized distributor.
     * @param recipient Address to receive the rescued tokens.
     * @param tokenAddress Address of the token contract to rescue.
     * @param amount Amount of tokens to rescue.
     */
    function rescueToken(address recipient, address tokenAddress, uint256 amount) external;
}
