// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Errors} from "./libraries/Errors.sol";

contract Vault is IVault, Initializable {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    address public factoryAddress;
    address public creator;
    address public tokenAddress;
    bool public isFinalized;
    bool public isFunded;
    uint256 public fundAmount;
    address public distributor;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Modifiers ---
    modifier onlyDistributor() {
        if (msg.sender != distributor) revert Errors.UnauthorizedDistributor();
        _;
    }

    // --- Initializer ---
    function initialize(address _factoryAddress, address _distributor, address _creator) public initializer {
        if (_factoryAddress == address(0)) revert Errors.ZeroAddress();
        factoryAddress = _factoryAddress;
        distributor = _distributor;
        creator = _creator;
    }

    // --- View Functions ---
    function getBalance() public view override returns (uint256) {
        if (tokenAddress == address(0)) return 0;
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getFundAmount() external view override returns (uint256) {
        return fundAmount;
    }

    function getCreator() external view override returns (address) {
        return creator;
    }

    function getTokenAddress() external view override returns (address) {
        return tokenAddress;
    }

    function getDistributor() external view override returns (address) {
        return distributor;
    }

    // --- Core Functions ---
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

    function rescueToken(address recipient, address _tokenAddress, uint256 amount) external override onlyDistributor {
        IERC20(_tokenAddress).safeTransfer(recipient, amount);
        emit TokenRescued(msg.sender, recipient, _tokenAddress, amount);
    }
}
