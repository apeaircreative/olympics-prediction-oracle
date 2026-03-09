#!/usr/bin/env bun
// Mock Bets: Place bets on prediction market

import { ethers } from 'ethers';

// Minimal ABI for PredictionMarket (assume buyYes/buyNo functions)
const PREDICTION_MARKET_ABI = [
    "function buyYes(uint256 marketId) payable",
    "function buyNo(uint256 marketId) payable",
    "function getBalance(address) view returns (uint256)"
];

const MARKET_ADDRESS = "0xfa96065F919762EFb7Bef68Edf9fb0559CC3e3a3";
const SEPOLIA_RPC = "https://sepolia.infura.io/v3/YOUR_INFURA_KEY"; // Replace with actual

async function placeBet(marketId: number, side: 'yes' | 'no', amountEth: string) {
    const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC);
    // Use private key for demo (in prod, wallet)
    const signer = new ethers.Wallet(process.env.CRE_ETH_PRIVATE_KEY!, provider);
    const contract = new ethers.Contract(MARKET_ADDRESS, PREDICTION_MARKET_ABI, signer);

    const amountWei = ethers.parseEther(amountEth);

    try {
        let tx;
        if (side === 'yes') {
            tx = await contract.buyYes(marketId, { value: amountWei });
        } else {
            tx = await contract.buyNo(marketId, { value: amountWei });
        }

        console.log(`Bet placed: ${side.toUpperCase()} ${amountEth} ETH on market ${marketId}`);
        console.log(`Tx Hash: ${tx.hash}`);

        await tx.wait();
        console.log('Bet confirmed!');

        const balance = await contract.getBalance(signer.address);
        console.log(`New Balance: ${ethers.formatEther(balance)} ETH`);
    } catch (error) {
        console.error(`Bet failed: ${error}`);
    }
}

// CLI
const args = process.argv.slice(2);
const marketId = parseInt(args[args.indexOf('--id') + 1]);
const side = args[args.indexOf('--side') + 1] as 'yes' | 'no';
const amount = args[args.indexOf('--amount') + 1];

if (marketId && side && amount) {
    placeBet(marketId, side, amount);
} else {
    console.log('Usage: bun mock-bets.ts --id <marketId> --side <yes|no> --amount <eth>');
}
