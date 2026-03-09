# Betting Flow

## Overview
Allow users to bet YES/NO on prediction markets with ETH.

## Betting Process

```mermaid
sequenceDiagram
    participant U as User
    participant PM as PredictionMarket
    participant P as Pools
    participant E as Events
    
    U->>PM: buyYes(marketId, 1 ETH)
    PM->>PM: Validate active
    PM->>P: Add to Yes pool
    PM->>E: emit PredictionMade
    PM-->>U: ✅ Confirmed
    
    Note over U,E: 💰 Or bet No:
    U->>PM: buyNo(marketId, 0.5 ETH)
    PM->>P: Add to No pool
    PM->>E: emit PredictionMade
```

## Steps
1. User selects market ID, side (yes/no), amount
2. Validate market exists, not settled
3. Call `buyYes` or `buyNo` on contract
4. Update pool balances
5. Emit PredictionMade event

## Files
- `contracts/src/PredictionMarket.sol` (buyYes/buyNo functions)
- `mock-bets.ts` (demo betting script)
- `place-mock-bets.sh` (demo script)

## ABI
```json
{
  "buyYes(uint256)": "payable",
  "buyNo(uint256)": "payable"
}
```

---

## 📚 Related Documentation
- [← System Architecture](../../README.md#-system-architecture)
- [Market Creation](./market-creation.md)
- [Settlement Flow](./settlement.md)
- [Chainlink Automation](./chainlink-automation.md)
