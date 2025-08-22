// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Reward {
    address recipient;
    uint256 amount;
}

event VaultFunded(address indexed creator, address indexed tokenAddress, uint256 amount);

event RewardsDistributed(address indexed distributor, Reward[] rewards, uint256 totalAmount);

event TokenRescued(
    address indexed distributor, address indexed recipient, address indexed tokenAddress, uint256 amount
);
