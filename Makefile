# Reward Campaign Vault System Makefile
# Simplifies common development and deployment tasks

# Load environment variables from .env file if it exists
-include .env
export

# Default target
.PHONY: help
help:
	@echo "Reward Campaign Vault System - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  make build          - Build the contracts"
	@echo "  make test           - Run all tests"
	@echo "  make test-verbose   - Run tests with verbose output"
	@echo "  make coverage       - Generate test coverage report"
	@echo "  make fmt            - Format code"
	@echo "  make clean          - Clean build artifacts"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy         - Deploy to configured network"
	@echo "  make deploy-local   - Deploy to local Anvil network"
	@echo "  make deploy-testnet - Deploy to testnet (requires TESTNET_RPC_URL)"
	@echo "  make deploy-mainnet - Deploy to mainnet (requires MAINNET_RPC_URL)"
	@echo ""
	@echo "Network Operations:"
	@echo "  make anvil          - Start local Anvil node"
	@echo "  make verify         - Verify contracts on Etherscan"
	@echo ""
	@echo "Utilities:"
	@echo "  make gas-snapshot   - Generate gas usage snapshots"
	@echo "  make check-env      - Validate environment configuration"
	@echo "  make env-template   - Create .env template file"

# Build contracts
.PHONY: build
build:
	@echo "Building contracts..."
	forge build

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	forge test

# Run tests with verbose output
.PHONY: test-verbose
test-verbose:
	@echo "Running tests with verbose output..."
	forge test -vvv

# Generate test coverage
.PHONY: coverage
coverage:
	@echo "Generating test coverage..."
	forge coverage

# Format code
.PHONY: fmt
fmt:
	@echo "Formatting code..."
	forge fmt

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	forge clean

# Generate gas snapshots
.PHONY: gas-snapshot
gas-snapshot:
	@echo "Generating gas snapshots..."
	forge snapshot

# Start local Anvil node
.PHONY: anvil
anvil:
	@echo "Starting Anvil local node..."
	anvil

# Check environment configuration
.PHONY: check-env
check-env:
	@echo "Checking environment configuration..."
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "❌ PRIVATE_KEY not set"; exit 1; fi
	@if [ -z "$(INITIAL_OWNER)" ]; then echo "❌ INITIAL_OWNER not set"; exit 1; fi
	@if [ -z "$(INITIAL_DISTRIBUTOR)" ]; then echo "❌ INITIAL_DISTRIBUTOR not set"; exit 1; fi
	@if [ -z "$(FEE_WALLET)" ]; then echo "❌ FEE_WALLET not set"; exit 1; fi
	@if [ -z "$(CAMPAIGN_FEE_PERCENTAGE)" ]; then echo "❌ CAMPAIGN_FEE_PERCENTAGE not set"; exit 1; fi
	@if [ -z "$(RPC_URL)" ] && [ -z "$(TESTNET_RPC_URL)" ] && [ -z "$(MAINNET_RPC_URL)" ]; then \
	echo "❌ You must set at least one of: RPC_URL, TESTNET_RPC_URL, or MAINNET_RPC_URL"; \
	exit 1; \
	else \
	echo "✅ RPC configuration looks good"; \
	fi
	@echo "✅ All required environment variables are set"

# Deploy to configured network
.PHONY: deploy
deploy: check-env build
	@echo "Deploying to network: $(RPC_URL)"
	@echo "Deployer: $$(cast wallet address $(PRIVATE_KEY) 2>/dev/null || echo 'Unable to derive address')"
	@echo "Initial Owner: $(INITIAL_OWNER)"
	@echo "Initial Distributor: $(INITIAL_DISTRIBUTOR)"
	@echo "Fee Wallet: $(FEE_WALLET)"
	@echo "Campaign Fee: $(CAMPAIGN_FEE_PERCENTAGE)%"
	@echo ""
	@echo "Continue with deployment? [y/N]"; \
	read confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Deployment cancelled."; \
		exit 1; \
	fi
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast 
	@echo ""
	@echo "✅ Deployment complete! Check deployment-addresses.txt for contract addresses."

# Deploy to local Anvil network
.PHONY: deploy-local
deploy-local: build
	@echo "Deploying to local Anvil network..."
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast
	@echo "✅ Local deployment complete!"

# Deploy to testnet
.PHONY: deploy-testnet
deploy-testnet: check-env build
	@if [ -z "$(TESTNET_RPC_URL)" ]; then echo "❌ TESTNET_RPC_URL not set"; exit 1; fi
	@echo "Deploying to testnet: $(TESTNET_RPC_URL)"
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url $(TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast 
	@echo "✅ Testnet deployment complete!"

# Deploy to mainnet
.PHONY: deploy-mainnet
deploy-mainnet: check-env build
	@if [ -z "$(MAINNET_RPC_URL)" ]; then echo "❌ MAINNET_RPC_URL not set"; exit 1; fi
	@echo "🚨 MAINNET DEPLOYMENT - This will deploy to production!"
	@echo "Network: $(MAINNET_RPC_URL)"
	@echo "Deployer: $$(cast wallet address $(PRIVATE_KEY) 2>/dev/null || echo 'Unable to derive address')"
	@echo "Gas Price: $$(cast gas-price --rpc-url $(MAINNET_RPC_URL) 2>/dev/null || echo 'Unable to fetch gas price')"
	@echo ""
	@echo "Are you absolutely sure you want to deploy to MAINNET? [y/N]"; \
	read confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Deployment cancelled."; \
		exit 1; \
	fi; \
	echo "Type 'DEPLOY' to confirm:"; \
	read confirm2; \
	if [ "$$confirm2" != "DEPLOY" ]; then \
		echo "Deployment cancelled."; \
		exit 1; \
	fi
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url $(MAINNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
	@echo "✅ Mainnet deployment complete!"

# Verify contracts on Etherscan
.PHONY: verify
verify: check-env
	@if [ ! -f "deployment-addresses.txt" ]; then echo "❌ deployment-addresses.txt not found. Deploy first."; exit 1; fi
	@echo "Verifying contracts on Etherscan..."
	@FACTORY_ADDRESS=$$(grep "FACTORY_ADDRESS" deployment-addresses.txt | cut -d'=' -f2 | tr -d '\r'); \
	VAULT_IMPL_ADDRESS=$$(grep "VAULT_IMPLEMENTATION_ADDRESS" deployment-addresses.txt | cut -d'=' -f2 | tr -d '\r'); \
	echo "Verifying Factory at $$FACTORY_ADDRESS..."; \
	forge verify-contract $$FACTORY_ADDRESS src/vault/Factory.sol:Factory --rpc-url $(RPC_URL) || echo "Factory verification failed"; \
	echo "Verifying Vault Implementation at $$VAULT_IMPL_ADDRESS..."; \
	forge verify-contract $$VAULT_IMPL_ADDRESS src/vault/Vault.sol:Vault --rpc-url $(RPC_URL) || echo "Vault verification failed"
	@echo "✅ Verification complete!"

# Create .env template
.PHONY: env-template
env-template:
	@echo "Creating .env template..."
	@echo "# Deployment Configuration" > .env.template
	@echo "PRIVATE_KEY=0x..." >> .env.template
	@echo "INITIAL_OWNER=0x..." >> .env.template
	@echo "INITIAL_DISTRIBUTOR=0x..." >> .env.template
	@echo "FEE_WALLET=0x..." >> .env.template
	@echo "CAMPAIGN_FEE_PERCENTAGE=5" >> .env.template
	@echo "" >> .env.template
	@echo "# Network URLs" >> .env.template
	@echo "RPC_URL=https://your-rpc-url" >> .env.template
	@echo "TESTNET_RPC_URL=https://your-testnet-rpc-url" >> .env.template
	@echo "MAINNET_RPC_URL=https://your-mainnet-rpc-url" >> .env.template
	@echo "" >> .env.template
	@echo "# Etherscan API Key (for verification)" >> .env.template
	@echo "ETHERSCAN_API_KEY=your-etherscan-api-key" >> .env.template
	@echo "✅ .env template created! Copy .env.template to .env and fill in your values."