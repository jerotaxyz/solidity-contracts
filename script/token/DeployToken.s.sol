// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Jerota} from "../../src/token/Jerota.sol";

contract DeployToken is Script {
    function run() external returns (Jerota) {
        // Get deployment parameters from environment
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        string memory network = vm.envString("NETWORK");

        console.log("Deploying Jerota token...");
        console.log("Network:", network);
        console.log("Initial Owner:", initialOwner);

        vm.startBroadcast();

        Jerota token = new Jerota(initialOwner);

        vm.stopBroadcast();

        console.log("Jerota deployed at:", address(token));
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Token Decimals:", token.decimals());
        console.log("Token Owner:", token.owner());

        // Save deployment address to file
        string memory deploymentFile = string.concat("deployment-addresses-", network, ".txt");
        string memory tokenAddress = vm.toString(address(token));

        // Append token address to deployment file
        vm.writeLine(deploymentFile, string.concat("JEROTA_TOKEN_ADDRESS=", tokenAddress));

        console.log("Deployment address saved to:", deploymentFile);

        return token;
    }
}
