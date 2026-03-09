# 🛠️ Developer Guide

**Quick setup for developers to get the Olympics Prediction Market running locally**

## 🧭 Navigation
- [← System Overview](../../README.md#-quick-start)
- [Olympics Demo](./olympics-demo.md) 🎭
- [Security Model](../architecture/security-model.md) 🛡️
- [Testing Suite](../../contracts/TESTING.md) 🧪

---

## 🔒 **Security First - Important!**

### ⚠️ **Never Commit Real Private Keys**
- Your `.env` file contains sensitive data
- It's already in `.gitignore` and will NOT be committed
- Use `.env.example` as a template for your setup

### 🛡️ **Safe Development Practices**
```bash
# Use the example file as template
cp .env.example .env
# Edit .env with YOUR private keys (never commit this file)

# For demo purposes, you can use testnet accounts
# Anvil provides test accounts with free ETH
anvil  # Shows 10 test accounts with private keys
```

---

## �🚀 Quick Start (5 Commands)

```bash
# 1️⃣ Install dependencies
forge install

# 2️⃣ Run tests (verify setup)
forge test --via-ir

# 3️⃣ Start local chain
anvil

# 4️⃣ Deploy contracts (new terminal)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 5️⃣ Run full demo
make demo
```

---

## 📋 Detailed Setup

### Prerequisites
- **Foundry**: `curl -L https://foundry.paradigm.xyz | bash`
- **Node.js**: `v18+` (for CRE workflows)
- **Make**: `brew install make` (macOS)

### 1. Install Dependencies
```bash
# Install Foundry libraries (OpenZeppelin, forge-std)
forge install

# Install Node.js dependencies for CRE workflows
npm install

# Install CRE workflow dependencies
npm run workflow:install
```

### 2. Verify Setup
```bash
# Run core test to verify everything works
forge test --match-test testCreateMarket --via-ir

# Expected output:
# [PASS] testCreateMarket() (gas: 224146)
# Suite result: ok. 1 passed; 0 failed
```

### 3. Start Local Development Chain
```bash
# Start Anvil (local Hardhat-like chain)
anvil

# Keep this terminal open - it's your local blockchain
# Default accounts: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (and 9 more)
```

### 4. Deploy Contracts
```bash
# In a NEW terminal (keep anvil running):
forge script contracts/script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# This deploys:
# - PredictionMarket contract
# - Sets up Chainlink Automation
# - Returns contract addresses
```

### 5. Run Demo
```bash
# Full Olympics prediction market demo
make demo

# Or run manually:
./scripts/demo/demo-olympics.sh
```

---

## 🎯 Common Development Tasks

### 🧪 Run Tests
```bash
# Core functionality test
forge test --match-test testCreateMarket --via-ir

# All tests (may have timing-related failures)
forge test --via-ir

# Specific test suites
forge test --match-contract PredictionMarketTest --via-ir
forge test --match-contract IntegrationTest --via-ir
forge test --match-contract AdversarialTest --via-ir
```

### 🔧 Local Development
```bash
# Start local chain with accounts
anvil

# Deploy to local chain
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Run CRE workflows locally
npm run workflow:dev

# Test settlement manually
npm run workflow:test
```

### 📊 Monitor & Debug
```bash
# Watch contract events
cast logs --rpc-url http://localhost:8545 <CONTRACT_ADDRESS>

# Check contract state
cast call <CONTRACT_ADDRESS> "getMarket(uint256)" 0

# Monitor Chainlink Automation
cast logs --rpc-url http://localhost:8545 <AUTOMATION_ADDRESS>
```

---

## 🏗️ Project Structure

```
contracts/
├── src/PredictionMarket.sol          # Main smart contract
├── test/                             # Test suites (309 tests passing)
└── TESTING.md                         # Test documentation

workflows/
├── workflow.ts                       # AI rephrasing + settlement
└── settlement/workflow.ts             # Tiny Math Engine consensus

scripts/
├── Deploy.s.sol                      # Contract deployment
└── demo/demo-olympics.sh             # Full demo script

docs/
├── flows/                            # Process documentation
├── architecture/                     # Technical architecture
└── guides/                           # Developer guides
```

---

## 🐛 Troubleshooting

### Common Issues

**"forge command not found"**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**"Stack too deep" compilation error**
```bash
# Use IR compiler
forge test --via-ir
forge build --via-ir
```

**"No files changed, compilation skipped"**
```bash
# Force rebuild
forge build --force
```

**CRE workflow errors**
```bash
# Reinstall workflow dependencies
npm run workflow:install
npm run workflow:build
```

### Get Help

1. **Check logs**: `anvil` shows transaction details
2. **Verify deployment**: `cast code <CONTRACT_ADDRESS> --rpc-url http://localhost:8545`
3. **Test individual components**: Run specific tests
4. **Check documentation**: See `docs/flows/` for detailed process guides

---

## 🚀 Production Deployment

### Sepolia Testnet
```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC --broadcast --verify

# Set environment variables
export SEPOLIA_RPC="https://sepolia.infura.io/v3/YOUR_KEY"
export PRIVATE_KEY="your_private_key"
```

### Mainnet
```bash
# ⚠️ ONLY AFTER THOROUGH TESTING
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC --broadcast --verify

# Current deployed addresses:
# Contract: 0xfa96065F919762EFb7Bef68Edf9fb0559CC3e3a3
# Automation: 0x516Cf68FA8030958056C1b68336258A93D709687
```

---

## 📚 Further Reading

- [System Architecture](../architecture/architecture.md) - Protocol overview
- [Testing Suite](../../contracts/TESTING.md) - 309 passing tests
- [Market Creation Flow](../flows/market-creation.md) - AI rephrasing
- [Settlement Engine](../flows/settlement.md) - Tiny Math Engine
- [Olympics Demo](./olympics-demo.md) - Complete walkthrough

---


