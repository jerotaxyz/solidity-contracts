// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

event CampaignCreated(uint256 indexed campaignId, address indexed creator, address vaultAddress);

event TokenAdded(address indexed tokenAddress);

event TokenRemoved(address indexed tokenAddress);

event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);

event FeePercentageUpdated(uint8 oldFeePercentage, uint8 newFeePercentage);

event FeeWalletUpdated(address indexed oldFeeWallet, address indexed newFeeWallet);
