#!/usr/bin/env bun
// Settlement Bot: Scheduled settlement with persistent market tracking

import { ethers } from 'ethers';
import { Cron } from 'croner';
import { readFileSync, writeFileSync, existsSync } from 'fs';

// Market data structure
interface Market {
    id: number;
    question: string;
    endTime: string;
    status: 'open' | 'settling' | 'settled';
}

const MARKETS_FILE = 'markets.json';

// Load markets from JSON
function loadMarkets(): Market[] {
    if (!existsSync(MARKETS_FILE)) return [];
    return JSON.parse(readFileSync(MARKETS_FILE, 'utf8'));
}

// Save markets to JSON
function saveMarkets(markets: Market[]) {
    writeFileSync(MARKETS_FILE, JSON.stringify(markets, null, 2));
}

// Add market
function addMarket(id: number, question: string, endTime: string) {
    const markets = loadMarkets();
    if (markets.find(m => m.id === id)) {
        console.log(`Market ${id} already exists`);
        return;
    }
    markets.push({ id, question, endTime, status: 'open' });
    saveMarkets(markets);
    console.log(`Added market ${id}: "${question}"`);
}

// List markets
function listMarkets() {
    const markets = loadMarkets();
    console.table(markets);
}

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Settle market with retry
async function settleMarket(marketId: number, retries = 3): Promise<boolean> {
    const payload = JSON.stringify({ marketId });

    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            // Run settlement workflow simulation
            const command = `echo '${payload}' | ./cre_bin workflow simulate ./workflow/settlement --target staging-settings`;
            const { stdout, stderr } = await execAsync(command, { cwd: process.cwd() });

            if (stdout.includes('settled via weighted consensus')) {
                console.log(`Market ${marketId} settled: simulated`);
                return true;
            } else {
                throw new Error('Settlement failed');
            }
        } catch (error) {
            console.error(`Attempt ${attempt} failed for market ${marketId}: ${error}`);
            if (attempt < retries) {
                await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
            }
        }
    }
    return false;
}

// Scheduled settlement check
async function checkSettlements() {
    const markets = loadMarkets();
    const now = new Date();

    for (const market of markets) {
        if (market.status === 'open' && new Date(market.endTime) <= now) {
            console.log(`Settling market ${market.id}...`);
            market.status = 'settling';
            saveMarkets(markets);

            const success = await settleMarket(market.id);
            market.status = success ? 'settled' : 'open'; // Reset on failure
            saveMarkets(markets);
        }
    }
}

// CLI handling
const args = process.argv.slice(2);
const command = args[0];

if (command === 'add') {
    const id = parseInt(args[args.indexOf('--id') + 1]);
    const question = args[args.indexOf('--question') + 1];
    const end = args[args.indexOf('--end') + 1];
    addMarket(id, question, end);
} else if (command === 'list') {
    listMarkets();
} else if (command === 'settle-now') {
    const id = parseInt(args[args.indexOf('--id') + 1]);
    settleMarket(id);
} else {
    // Start CRON scheduler (every 2 hours during Olympics: Feb 10-13)
    const job = new Cron('0 */2 10-13 2 *', checkSettlements);
    // Keep running
    process.on('SIGINT', () => {
        console.log('Bot stopped');
        process.exit(0);
    });
}
