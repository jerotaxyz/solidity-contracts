# Reward Campaign Vault System

A decentralized reward distribution system built on Ethereum that allows creators to set up token-based reward campaigns with secure, automated distribution mechanisms.

## Overview

The Reward Campaign Vault System consists of two main contracts that work together to provide a secure and efficient way to manage token-based reward campaigns:

- **Factory Contract**: Deploys and manages individual campaign vaults using minimal proxy clones for gas efficiency
- **Vault Contract**: Handles individual campaign funding, storage, and reward distribution

## Key Features

### 🏭 Factory Contract
- **Campaign Creation**: Deploy new reward campaigns as gas-efficient minimal proxy clones
- **Token Allowlist**: Maintain a whitelist of approved ERC20 tokens for campaigns
- **Fee Management**: Configurable fee system with designated fee wallet
- **Distributor Management**: Centralized reward distributor authorization
- **Upgrade Mechanism**: Update vault implementation for new campaigns without affecting existing ones

### 🏦 Vault Contract
- **Secure Funding**: Campaign creators fund their vaults with approved ERC20 tokens
- **Automated Fee Deduction**: Fees are automatically deducted during funding
- **Batch Reward Distribution**: Distribute rewards to multiple recipients in a single transaction
- **Campaign Finalization**: One-time reward distribution with permanent campaign closure
- **Token Recovery**: Rescue mechanism for accidentally sent tokens

## Architecture

```
Factory Contract
├── Creates minimal proxy clones of Vault implementation
├── Manages token allowlist and fee configuration
├── Authorizes reward distributors
└── Tracks all deployed campaigns

Vault Contract (Proxy)
├── Initialized by Factory with campaign-specific parameters
├── Funded by campaign creator with approved tokens
├── Distributes rewards via authorized distributor
└── Finalizes campaign after distribution
```

## Workflow

1. **Campaign Creation**: User calls `createCampaign()` on Factory
2. **Vault Deployment**: Factory deploys a minimal proxy clone of Vault
3. **Campaign Funding**: Creator funds the vault with approved ERC20 tokens
4. **Fee Processing**: Factory fee is automatically deducted and sent to fee wallet
5. **Reward Distribution**: Authorized distributor distributes rewards to recipients
6. **Campaign Finalization**: Vault is permanently finalized after distribution

## Security Features

- **Access Control**: Only authorized distributors can distribute rewards
- **One-Time Distribution**: Campaigns can only be finalized once
- **Token Allowlist**: Only pre-approved tokens can be used for campaigns
- **Initialization Protection**: Vaults cannot be re-initialized after deployment
- **Safe Token Transfers**: Uses OpenZeppelin's SafeERC20 for secure token operations

## Gas Optimization

- **Minimal Proxy Pattern**: Reduces deployment costs by ~90% compared to full contract deployment
- **Batch Operations**: Distribute rewards to multiple recipients in single transaction
- **Efficient Storage**: Optimized state variable packing and access patterns

## Foundry Development Environment

This project uses **Foundry**, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

Foundry consists of:
-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools)
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL

## Contract Addresses

After deployment, update this section with the deployed contract addresses:

```
Factory: 0x...
Vault Implementation: 0x...
```

## Usage Examples

### Creating a Campaign

```solidity
// 1. Deploy or get Factory contract instance
IFactory factory = IFactory(FACTORY_ADDRESS);

// 2. Create a new campaign
address vaultAddress = factory.createCampaign();
```

### Funding a Campaign

```solidity
// 1. Get vault instance
IVault vault = IVault(vaultAddress);

// 2. Approve tokens for transfer
IERC20(tokenAddress).approve(vaultAddress, fundingAmount);

// 3. Fund the vault (fees are automatically deducted)
vault.fund(tokenAddress, fundingAmount);
```

### Distributing Rewards

```solidity
// 1. Prepare reward array
IVault.Reward[] memory rewards = new IVault.Reward[](2);
rewards[0] = IVault.Reward(recipient1, amount1);
rewards[1] = IVault.Reward(recipient2, amount2);

// 2. Distribute rewards (only authorized distributor)
vault.distributeRewards(rewards);
```

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

#### Quick Start with Makefile

This project includes a Makefile for simplified operations. First, create your environment configuration:

```shell
# Create .env template
$ make env-template

# Copy and edit the template
$ cp .env.template .env
# Edit .env with your actual values
```

Then deploy using the Makefile:

```shell
# Deploy to configured network
$ make deploy

# Or deploy to specific networks
$ make deploy-local    # Local Anvil
$ make deploy-testnet  # Testnet
$ make deploy-mainnet  # Mainnet (with safety prompts)
```

#### Manual Deployment

Alternatively, deploy manually with Forge:

```shell
$ forge script script/vault/DeployFactory.s.sol:DeployFactory --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

The deployment addresses will be saved to `deployment-addresses-{NETWORK}.txt`.

#### Available Make Commands

```shell
$ make help  # Show all available commands
```

Common commands:
- `make build` - Build contracts
- `make test` - Run tests
- `make deploy` - Deploy to configured network
- `make verify` - Verify contracts on Etherscan
- `make anvil` - Start local development node

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
