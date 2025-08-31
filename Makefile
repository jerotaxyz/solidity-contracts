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
	@echo "  make test-token     - Run token tests only"
	@echo "  make test-token-gas - Run token tests with gas report"
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
	@echo "Token Deployment:"
	@echo "  make deploy-token         - Deploy Jerota token to configured network"
	@echo "  make deploy-token-local   - Deploy Jerota token to local Anvil network"
	@echo "  make deploy-token-testnet - Deploy Jerota token to testnet"
	@echo "  make deploy-token-mainnet - Deploy Jerota token to mainnet"
	@echo ""
	@echo "Network Operations:"
	@echo "  make anvil          - Start local Anvil node"
	@echo ""
	@echo "Utilities:"
	@echo "  make gas-snapshot   - Generate gas usage snapshots"
	@echo "  make check-env      - Validate environment configuration"
	@echo "  make env-template   - Create .env template file"
	@echo ""
	@echo "Verification:"
	@echo "  make verify-manual  - Show manual verification commands"
	@echo "  make verify-simple  - Try verification without API key"
	@echo ""
	@echo "Note: All deployment commands include automatic contract verification"

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
	@if [ -z "$(NETWORK)" ]; then echo "❌ NETWORK not set"; exit 1; fi
	@echo "✅ All required environment variables are set"

# Deploy to configured network
.PHONY: deploy
deploy: check-env build
	@echo "Deploying to network: $(RPC_URL)"
	@echo "Network: $(NETWORK)"
	@echo "Deployer: $$(cast wallet address $(PRIVATE_KEY) 2>/dev/null || echo 'Unable to derive address')"
	@echo "Initial Owner: $(INITIAL_OWNER)"
	@echo "Initial Distributor: $(INITIAL_DISTRIBUTOR)"
	@echo "Fee Wallet: $(FEE_WALLET)"
	@echo "Campaign Fee: $(CAMPAIGN_FEE_PERCENTAGE)%"
	@echo ""
	@echo "Continue with deployment? [Y/n]"; \
	read confirm; \
	if [ "$$confirm" = "n" ] || [ "$$confirm" = "N" ]; then \
		echo "Deployment cancelled."; \
		exit 1; \
	fi
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
	@echo ""
	@echo "✅ Deployment complete! Check deployment-addresses-$(NETWORK).txt for contract addresses."
	@echo "🔍 Starting contract verification..."
	@$(MAKE) verify-contracts

# Deploy to local Anvil network
.PHONY: deploy-local
deploy-local: build
	@echo "Deploying to local Anvil network..."
	@export NETWORK=Local; \
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast
	@echo "✅ Local deployment complete! Check deployment-addresses-Local.txt"

# Deploy to testnet
.PHONY: deploy-testnet
deploy-testnet: check-env build
	@if [ -z "$(TESTNET_RPC_URL)" ]; then echo "❌ TESTNET_RPC_URL not set"; exit 1; fi
	@echo "Deploying to testnet: $(TESTNET_RPC_URL)"
	forge script script/vault/DeployFactory.s.sol:DeployFactory \
		--rpc-url $(TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
	@echo "✅ Testnet deployment complete! Check deployment-addresses-$(NETWORK).txt"
	@echo "🔍 Starting contract verification..."
	@$(MAKE) verify-contracts

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
		--broadcast
	@echo "✅ Mainnet deployment complete! Check deployment-addresses-$(NETWORK).txt"
	@echo "🔍 Starting contract verification..."
	@$(MAKE) verify-contracts



# Verify contracts on Celoscan (called automatically after deployment)
.PHONY: verify-contracts
verify-contracts:
	@DEPLOYMENT_FILE="deployment-addresses-$(NETWORK).txt"; \
	if [ ! -f "$$DEPLOYMENT_FILE" ]; then \
		echo "❌ $$DEPLOYMENT_FILE not found. Deploy first."; \
		exit 1; \
	fi; \
	echo "Verifying contracts on Celoscan..."; \
	FACTORY_ADDRESS=$$(grep "FACTORY_ADDRESS" $$DEPLOYMENT_FILE | cut -d'=' -f2 | tr -d '\r'); \
	VAULT_IMPL_ADDRESS=$$(grep "VAULT_IMPLEMENTATION_ADDRESS" $$DEPLOYMENT_FILE | cut -d'=' -f2 | tr -d '\r'); \
	echo "Verifying Vault Implementation at $$VAULT_IMPL_ADDRESS..."; \
	forge verify-contract $$VAULT_IMPL_ADDRESS \
		src/vault/Vault.sol:Vault \
		--chain celo --watch || \
		echo "⚠️  Vault verification failed"; \
	echo "Verifying Factory at $$FACTORY_ADDRESS..."; \
	forge verify-contract $$FACTORY_ADDRESS \
		src/vault/Factory.sol:Factory \
		--chain celo --watch \
		--constructor-args $$(cast abi-encode "constructor(address,address,address,address,uint8)" $(INITIAL_OWNER) $$VAULT_IMPL_ADDRESS $(INITIAL_DISTRIBUTOR) $(FEE_WALLET) $(CAMPAIGN_FEE_PERCENTAGE)) || echo "⚠️  Factory verification failed"
	@echo "✅ Contract verification complete!"

# Manual verification command (if automatic fails)
.PHONY: verify-manual
verify-manual: check-env
	@echo "Manual contract verification..."
	@DEPLOYMENT_FILE="deployment-addresses-$(NETWORK).txt"; \
	if [ ! -f "$$DEPLOYMENT_FILE" ]; then \
		echo "❌ $$DEPLOYMENT_FILE not found. Deploy first."; \
		exit 1; \
	fi; \
	FACTORY_ADDRESS=$$(grep "FACTORY_ADDRESS" $$DEPLOYMENT_FILE | cut -d'=' -f2 | tr -d '\r'); \
	VAULT_IMPL_ADDRESS=$$(grep "VAULT_IMPLEMENTATION_ADDRESS" $$DEPLOYMENT_FILE | cut -d'=' -f2 | tr -d '\r'); \
	echo ""; \
	echo "📋 Manual Verification Commands:"; \
	echo ""; \
	echo "Vault Implementation:"; \
	echo "forge verify-contract $$VAULT_IMPL_ADDRESS src/vault/Vault.sol:Vault --chain celo-alfajores --watch \
	echo ""; \
	echo "Factory:"; \
	echo "forge verify-contract $$FACTORY_ADDRESS src/vault/Factory.sol:Factory --chain celo-alfajores --watch --constructor-args $$(cast abi-encode \"constructor(address,address,address,address,uint8)\" $(INITIAL_OWNER) $$VAULT_IMPL_ADDRESS $(INITIAL_DISTRIBUTOR) $(FEE_WALLET) $(CAMPAIGN_FEE_PERCENTAGE))"; \
	echo ""; \
	echo "📋 Alternative: Try without API key (Celoscan might not require it):"; \
	echo "forge verify-contract $$VAULT_IMPL_ADDRESS src/vault/Vault.sol:Vault --chain celo-alfajores --watch"; \
	echo "forge verify-contract $$FACTORY_ADDRESS src/vault/Factory.sol:Factory --chain celo-alfajores --watch --constructor-args $$(cast abi-encode \"constructor(address,address,address,address,uint8)\" $(INITIAL_OWNER) $$VAULT_IMPL_ADDRESS $(INITIAL_DISTRIBUTOR) $(FEE_WALLET) $(CAMPAIGN_FEE_PERCENTAGE))"; \
	echo ""

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
	@echo "NETWORK=YourNetworkName" >> .env.template
	@echo "" >> .env.template
	@echo "# Network URLs" >> .env.template
	@echo "RPC_URL=https://your-rpc-url" >> .env.template
	@echo "TESTNET_RPC_URL=https://your-testnet-rpc-url" >> .env.template
	@echo "MAINNET_RPC_URL=https://your-mainnet-rpc-url" >> .env.template
	@echo "" >> .env.template
	@echo "# Celoscan API Key (for verification)" >> .env.template
	@echo "CELOSCAN_API_KEY=your-celoscan-api-key" >> .env.template
	@echo "✅ .env template created! Copy .env.template to .env and fill in your values."

# Token Deployment Commands

# Deploy Jerota token to configured network
.PHONY: deploy-token
deploy-token: check-env build
	@echo "Deploying Jerota token to network: $(RPC_URL)"
	@echo "Network: $(NETWORK)"
	@echo "Deployer: $(cast wallet address $(PRIVATE_KEY) 2>/dev/null || echo 'Unable to derive address')"
	@echo "Initial Owner: $(INITIAL_OWNER)"
	@echo ""
	@echo "Continue with token deployment? [Y/n]"; \
	read confirm; \
	if [ "$$confirm" = "n" ] || [ "$$confirm" = "N" ]; then \
		echo "Token deployment cancelled."; \
		exit 1; \
	fi
	forge script script/token/DeployToken.s.sol:DeployToken \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
	@echo ""
	@echo "✅ Jerota token deployment complete! Check deployment-addresses-$(NETWORK).txt for token address."
	@echo "🔍 Starting token contract verification..."
	@$(MAKE) verify-token

# Deploy Jerota token to local Anvil network
.PHONY: deploy-token-local
deploy-token-local: build
	@echo "Deploying Jerota token to local Anvil network..."
	@export NETWORK=Local; \
	forge script script/token/DeployToken.s.sol:DeployToken \
		--rpc-url http://localhost:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast
	@echo "✅ Local Jerota token deployment complete! Check deployment-addresses-Local.txt"

# Deploy Jerota token to testnet
.PHONY: deploy-token-testnet
deploy-token-testnet: check-env build
	@if [ -z "$(TESTNET_RPC_URL)" ]; then echo "❌ TESTNET_RPC_URL not set"; exit 1; fi
	@echo "Deploying Jerota token to testnet: $(TESTNET_RPC_URL)"
	forge script script/token/DeployToken.s.sol:DeployToken \
		--rpc-url $(TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
	@echo "✅ Testnet Jerota token deployment complete! Check deployment-addresses-$(NETWORK).txt"
	@echo "🔍 Starting token contract verification..."
	@$(MAKE) verify-token

# Deploy Jerota token to mainnet
.PHONY: deploy-token-mainnet
deploy-token-mainnet: check-env build
	@if [ -z "$(MAINNET_RPC_URL)" ]; then echo "❌ MAINNET_RPC_URL not set"; exit 1; fi
	@echo "🚨 MAINNET TOKEN DEPLOYMENT - This will deploy to production!"
	@echo "Network: $(MAINNET_RPC_URL)"
	@echo "Deployer: $(cast wallet address $(PRIVATE_KEY) 2>/dev/null || echo 'Unable to derive address')"
	@echo "Gas Price: $(cast gas-price --rpc-url $(MAINNET_RPC_URL) 2>/dev/null || echo 'Unable to fetch gas price')"
	@echo ""
	@echo "Are you absolutely sure you want to deploy Jerota token to MAINNET? [y/N]"; \
	read confirm; \
	if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then \
		echo "Token deployment cancelled."; \
		exit 1; \
	fi; \
	echo "Type 'DEPLOY-TOKEN' to confirm:"; \
	read confirm2; \
	if [ "$confirm2" != "DEPLOY-TOKEN" ]; then \
		echo "Token deployment cancelled."; \
		exit 1; \
	fi
	forge script script/token/DeployToken.s.sol:DeployToken \
		--rpc-url $(MAINNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
	@echo "✅ Mainnet Jerota token deployment complete! Check deployment-addresses-$(NETWORK).txt"
	@echo "🔍 Starting token contract verification..."
	@$(MAKE) verify-token

# Verify Jerota token on Celoscan
.PHONY: verify-token
verify-token:
	@DEPLOYMENT_FILE="deployment-addresses-$(NETWORK).txt"; \
	if [ ! -f "$$DEPLOYMENT_FILE" ]; then \
		echo "❌ $$DEPLOYMENT_FILE not found. Deploy token first."; \
		exit 1; \
	fi; \
	if ! grep -q "JEROTA_TOKEN_ADDRESS" "$$DEPLOYMENT_FILE"; then \
		echo "❌ JEROTA_TOKEN_ADDRESS not found in $$DEPLOYMENT_FILE. Deploy token first."; \
		exit 1; \
	fi; \
	echo "Verifying Jerota token on Celoscan..."; \
	TOKEN_ADDRESS=$$(grep "JEROTA_TOKEN_ADDRESS" $$DEPLOYMENT_FILE | cut -d'=' -f2 | tr -d '\r'); \
	echo "Verifying Jerota Token at $$TOKEN_ADDRESS..."; \
	forge verify-contract $$TOKEN_ADDRESS \
		src/token/Jerota.sol:Jerota \
		--chain celo --watch \
		--constructor-args $$(cast abi-encode "constructor(address)" $(INITIAL_OWNER)) || \
		echo "⚠️  Jerota token verification failed"
	@echo "✅ Jerota token verification complete!"

# Test token contracts specifically
.PHONY: test-token
test-token:
	@echo "Running Jerota token tests..."
	forge test --match-path "test/token/*" -vv

# Test token contracts with gas report
.PHONY: test-token-gas
test-token-gas:
	@echo "Running Jerota token tests with gas report..."
	forge test --match-path "test/token/*" --gas-report