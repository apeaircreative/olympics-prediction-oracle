// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {console} from "forge-std/console.sol";

contract DeployPredictionMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("CRE_ETH_PRIVATE_KEY");
        
        // Sepolia Chainlink Forwarder address (Standard for CRE Bootcamp)
        address forwarder = 0x32358890C8eA78B896179b7E4F16ebC610408542;

        vm.startBroadcast(deployerPrivateKey);

        PredictionMarket market = new PredictionMarket(forwarder);
        
        console.log("PredictionMarket deployed at:", address(market));
        console.log("Forwarder address set to:", forwarder);

        vm.stopBroadcast();
    }
}
