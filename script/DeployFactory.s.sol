// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/vault/Factory.sol";
import {Vault} from "../src/vault/Vault.sol";

/**
 * @title DeployFactory
 * @notice A Foundry script to deploy the Vault implementation and the Factory contract.
 * @dev This script reads configuration from a .env file and saves the deployed addresses
 *      to a file using vm.writeFile.
 */
contract DeployFactory is Script {
    function run() public returns (Factory, address) {
        // --- Load Deployment Configuration ---
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address initialDistributor = vm.envAddress("INITIAL_DISTRIBUTOR");
        address feeWallet = vm.envAddress("FEE_WALLET");
        uint8 campaignFeePercentage = uint8(vm.envUint("CAMPAIGN_FEE_PERCENTAGE"));
        string memory rpc = vm.envString("RPC_URL");
        string memory network = "Local";

        require(deployerPrivateKey != 0, "PRIVATE_KEY must be set in .env");
        require(initialOwner != address(0), "INITIAL_OWNER must be set in .env");
        require(initialDistributor != address(0), "INITIAL_DISTRIBUTOR must be set in .env");
        require(feeWallet != address(0), "FEE_WALLET must be set in .env");
        require(campaignFeePercentage <= 100, "CAMPAIGN_FEE_PERCENTAGE must be <= 100");

        console.log("Deploying on network:", rpc);
        console.log("Deployer Address:", vm.addr(deployerPrivateKey));

        // --- Start Deployment Broadcast ---
        vm.startBroadcast(deployerPrivateKey);

        // --- Deploy the Vault Implementation ---
        console.log("Deploying Vault implementation...");
        Vault vaultImplementation = new Vault();

        // --- Deploy the Factory ---
        console.log("Deploying Factory...");
        Factory factory = new Factory(
            initialOwner, address(vaultImplementation), initialDistributor, feeWallet, campaignFeePercentage
        );

        // --- Stop Deployment Broadcast ---
        vm.stopBroadcast();

        // --- Print and Save Deployment Summary ---
        address vaultImplementationAddress = address(vaultImplementation);
        address factoryAddress = address(factory);

        console.log("\n=== Deployment Summary ===");
        console.log("Vault Implementation Address:", vaultImplementationAddress);
        console.log("Factory Address:", factoryAddress);
        console.log("=========================\n");

        // Prepare the content to be written to the file.
        string memory deploymentInfo = string(
            abi.encodePacked(
                "NETWORK=",
                network,
                "\n",
                "VAULT_IMPLEMENTATION_ADDRESS=",
                vm.toString(vaultImplementationAddress),
                "\n",
                "FACTORY_ADDRESS=",
                vm.toString(factoryAddress),
                "\n"
            )
        );

        // Define the output file path.
        string memory filePath = "./deployment-addresses.txt";

        // Write the deployment info to the file.
        vm.writeFile(filePath, deploymentInfo);
        console.log("Deployment addresses saved to", filePath);

        return (factory, vaultImplementationAddress);
    }
}
