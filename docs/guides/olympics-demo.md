# 🎭 Olympics Demo Guide

## Overview
Complete walkthrough of the 2026 Winter Olympics Men's Figure Skating prediction market demo.

## 🚀 Quick Demo

### One-Command Demo
```bash
make demo
```

### Manual Demo Steps
```bash
# 1. Start local blockchain
anvil

# 2. Deploy contracts (new terminal)
forge script contracts/script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 3. Run demo script
./scripts/demo/demo-olympics.sh
```

## 📋 Demo Scenario

### 🏅 Event Context
**Competition**: 2026 Winter Olympics - Men's Singles Figure Skating  
**Focus**: Ilia Malinin vs Yuma Kagiyama rivalry  
**Timeline**: February 10-13, 2026  

### 🎯 Demo Markets

#### Market 1: Gold Medal Prediction
- **Question**: "Will Ilia Malinin win men's singles gold at 2026 Olympics?"
- **Type**: Binary outcome (Yes/No)
- **Duration**: 7 days
- **Settlement**: Olympic official results

#### Market 2: Head-to-Head Performance
- **Question**: "Will Yuma Kagiyama score higher than Ilia Malinin in free skate?"
- **Type**: Binary outcome (Yes/No)
- **Duration**: 7 days
- **Settlement**: ISU official scores

#### Market 3: Technical Achievement
- **Question**: "Will Ilia Malinin successfully land a quadruple axel jump?"
- **Type**: Binary outcome (Yes/No)
- **Duration**: 7 days
- **Settlement**: Technical panel review

## 🎬 Demo Walkthrough

### Phase 1: Market Creation
```bash
# Create market with slang question
curl -X POST http://localhost:3000/create-market \
  -H "Content-Type: application/json" \
  -d '{"question": "Will Ilia moon gold?"}'

# AI rephrases to: "Will Ilia Malinin win gold at 2026 Olympics?"
# Market created on-chain with ID: 0
```

### Phase 2: Betting
```bash
# Place YES bet (1 ETH)
./scripts/demo/mock-bets.ts --market 0 --side yes --amount 1

# Place NO bet (0.5 ETH)
./scripts/demo/mock-bets.ts --market 0 --side no --amount 0.5

# Pool balances updated
# Yes pool: 1 ETH
# No pool: 0.5 ETH
```

### Phase 3: Settlement
```bash
# Trigger automated settlement (every 2 hours)
./scripts/demo/settlement-bot.ts --market 0

# Oracle consensus process:
# 1. Fetch from 4 sources
# 2. Calculate weighted consensus
# 3. Report settlement on-chain
# 4. Update market state
```

### Phase 4: Claiming
```bash
# Claim winnings for correct prediction
./scripts/demo/claim-winnings.ts --market 0 --user <address>

# Payout calculated based on pool ratios
# Yes bettors receive: (1.5 ETH * 1/1.5) = 1 ETH
# No bettors receive: 0 ETH (lost bet)
```

## 📊 Demo Results

### Expected Outcomes
- **Market Creation**: ✅ AI rephrased question
- **Betting**: ✅ Pools updated correctly
- **Settlement**: ✅ Oracle consensus achieved
- **Claiming**: ✅ Winnings distributed

### Performance Metrics
- **Market Creation Gas**: ~224,146
- **Betting Gas**: ~45,000 per bet
- **Settlement Gas**: ~89,000
- **Claiming Gas**: ~32,000

## 🎯 Advanced Features

### 🤖 AI Rephrasing
- **Input**: "Will Ilia moon gold?"
- **Output**: "Will Ilia Malinin win gold at 2026 Olympics?"
- **Benefit**: Professional, standardized questions

### ⚖️ 4-Source Consensus
- **ISU Official**: Technical scores and rankings
- **Olympics API**: Official Olympic results
- **Sportradar**: Professional sports data
- **News Sources**: Verified reporting

### 🔄 Dynamic Weighting
- **Source Reliability**: Tracked over time
- **Confidence Scoring**: Threshold-based decisions
- **Adaptation**: Machine learning improvements

## 🔧 Troubleshooting

### Common Issues
```bash
# If anvil isn't running
pkill -f anvil && anvil

# If contracts aren't deployed
forge script contracts/script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# If demo script fails
./scripts/demo/demo-olympics.sh --debug
```

### Verification Steps
```bash
# Check contract deployment
cast code <CONTRACT_ADDRESS> --rpc-url http://localhost:8545

# Verify market creation
cast call <CONTRACT_ADDRESS> "getMarket(uint256)" 0 --rpc-url http://localhost:8545

# Check oracle status
./scripts/demo/check-oracle.ts
```

## 📈 Extensions

### Additional Markets
- **Multiple Events**: Add skating disciplines
- **Parimutuel Betting**: Pool-based odds
- **Liquidity Mining**: Reward providers

### Enhanced Features
- **Real-time UI**: Web interface
- **Mobile App**: iOS/Android support
- **Analytics Dashboard**: Betting insights

---

## 📚 Related Documentation
- [← Developer Guide](./developer-guide.md)
- [Market Creation Flow](../flows/market-creation.md)
- [Betting Flow](../flows/betting.md)
- [Settlement Flow](../flows/settlement.md)
- [System Architecture](../architecture/architecture.md)
