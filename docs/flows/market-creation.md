# Market Creation Flow

## 🧭 Navigation
- [← System Architecture](../README.md#-system-architecture)
- [Betting Flow](./betting.md) →
- [Settlement Flow](./settlement.md) →
- [Developer Guide](../guides/developer-guide.md) 📚

---

## Overview
Transform slang-heavy user questions into professional prediction markets using AI rephrasing.

## Process Flow

```mermaid
flowchart TD
    A[📝 User Input] --> B{🤖 Slang?}
    B -->|Yes| C[🧠 Gemini AI]
    B -->|No| D[✅ Original]
    C --> E[📋 Rephrase]
    E --> F[🏗️ Create Market]
    D --> F
    F --> G[📊 Track Bot]
    G --> H[🟢 Active]
    
    style A fill:#e1f5fe
    style C fill:#f3e5f5
    style F fill:#e8f5e8
    style H fill:#c8e6c9
```

## Steps
1. User inputs slang question (e.g., "Will Ilia moon gold?")
2. Detect slang keywords ("moon", "rekt", "ape")
3. If slang detected, call Gemini API to rephrase
4. Create on-chain market with rephrased question
5. Track market in settlement bot database

## Files
- `workflows/workflow.ts` (main logic)
- `scripts/demo/demo-olympics.sh` (demo script)
- `scripts/demo/create_payload.json` (input example)

## Output
JSON: `{"status": "Success", "message": "Market created: \"Will Ilia win gold?\"", "links": {...}}`

---

## 📚 Related Documentation
- [← System Architecture](../../README.md#-system-architecture)
- [Betting Flow](./betting.md)
- [Settlement Flow](./settlement.md)
- [Chainlink Automation](./chainlink-automation.md)
