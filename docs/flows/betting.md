# Betting Flow

## Overview
Allow users to bet YES/NO on prediction markets with ETH.

## Betting Process

```mermaid
sequenceDiagram
    participant User as User
    participant PM as PredictionMarket
    participant Pool as Yes/No Pools
    participant Events as Event Emitter
    
    User->>PM: buyYes(marketId, 1 ETH)
    PM->>PM: Validate market active
    PM->>Pool: Add 1 ETH to Yes pool
    PM->>Events: emit PredictionMade(marketId, User, Yes, 1 ETH)
    PM-->>User: Bet confirmed
    
    Note over User,Events: User can also bet No
    User->>PM: buyNo(marketId, 0.5 ETH)
    PM->>Pool: Add 0.5 ETH to No pool
    PM->>Events: emit PredictionMade(marketId, User, No, 0.5 ETH)
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
