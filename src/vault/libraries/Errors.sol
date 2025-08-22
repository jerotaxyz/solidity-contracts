// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
    // --- Factory Errors ---
    error ZeroAddress();
    error InvalidDistributor();
    error InvalidClassHash();
    error InvalidFeeWallet();
    error InvalidFeePercentage();
    error InvalidTokenAddress();
    error VaultNotFound();

    // --- Vault Errors ---
    error TokenNotAllowed();
    error AlreadyFunded();
    error InvalidAmount();
    error OnlyCreatorCanFund();
    error TransferFailed();
    error CampaignFinalized();
    error ArrayLengthMismatch();
    error InsufficientFunds();
    error UnauthorizedDistributor();
    error UnauthorizedUpgrade();
}
