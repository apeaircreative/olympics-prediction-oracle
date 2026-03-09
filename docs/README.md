# 📚 Documentation Index

## 🧭 Quick Navigation

### 🏗️ **System Architecture**
- [System Overview](../README.md#-system-architecture) - Main protocol documentation
- [Architecture Deep Dive](./architecture/architecture.md) - Technical architecture details
- [Oracle Data Pipeline](./architecture/oracle-data-pipeline.md) - 4-source consensus system
- [Security Model](./architecture/security-model.md) - Multi-layer security approach

### 🔄 **Process Flows**
- [Market Creation](./flows/market-creation.md) - AI rephrasing and deployment
- [Betting System](./flows/betting.md) - YES/NO betting with ETH
- [Settlement Engine](./flows/settlement.md) - Tiny Math Engine consensus
- [Chainlink Automation](./flows/chainlink-automation.md) - CRON scheduling and triggers

### 📖 **Guides & Tutorials**
- [Developer Guide](./guides/developer-guide.md) - Setup and development
- [Olympics Demo](./guides/olympics-demo.md) - Complete walkthrough

### 🧪 **Testing & Quality**
- [Testing Suite](../contracts/TESTING.md) - 309 passing tests, security scenarios

---

## 🎯 **Getting Started**

### For Hackathon Judges
1. **Quick Demo**: `make demo` - See the system in action
2. **Developer Setup**: [Developer Guide](./guides/developer-guide.md) - 5-command setup
3. **Architecture Overview**: [System Architecture](./architecture/architecture.md) - Understand the design

### For Developers
1. **Security First**: Read [Security Model](./architecture/security-model.md)
2. **Local Setup**: Follow [Developer Guide](./guides/developer-guide.md)
3. **Testing**: Check [Testing Suite](../contracts/TESTING.md)

### For Security Researchers
1. **Threat Model**: [Security Model](./architecture/security-model.md)
2. **Test Coverage**: [Testing Suite](../contracts/TESTING.md)
3. **Oracle Security**: [Oracle Data Pipeline](./architecture/oracle-data-pipeline.md)

---

## 📊 **Documentation Structure**

```
docs/
├── 📁 architecture/          # System design and security
│   ├── architecture.md       # Protocol overview
│   ├── oracle-data-pipeline.md # 4-source consensus
│   └── security-model.md      # Security architecture
├── 📁 flows/                 # Process documentation
│   ├── market-creation.md    # AI rephrasing flow
│   ├── betting.md            # Betting process
│   ├── settlement.md         # Settlement engine
│   └── chainlink-automation.md # Automation setup
├── 📁 guides/                # Tutorials and setup
│   ├── developer-guide.md    # Development setup
│   └── olympics-demo.md       # Complete demo
└── 📄 README.md              # This index file
```

---

## 🔗 **External Resources**

### 📋 **Contract Links**
- **Prediction Market**: [0xfa96065F919762EFb7Bef68Edf9fb0559CC3e3a3](https://etherscan.io/address/0xfa96065F919762EFb7Bef68Edf9fb0559CC3e3a3)
- **Chainlink Automation**: [0x516Cf68FA8030958056C1b68336258A93D709687](https://etherscan.io/address/0x516Cf68FA8030958056C1b68336258A93D709687)

### 🌐 **Project Links**
- **GitHub Repository**: [apeaircreative/olympics-prediction-oracle](https://github.com/apeaircreative/olympics-prediction-oracle)
- **Hackathon Submission**: Chainlink Convergence 2026

---

## 🏆 **Hackathon Highlights**

### 🎯 **Target Tracks**
- **Prediction Markets Track** ($16k pool) - Binary prediction markets
- **CRE & AI Track** ($17k pool) - Chainlink CRE + Google Gemini

### 🛡️ **Security Features**
- Multi-source oracle consensus
- Adversarial testing (309 tests passing)
- Dynamic weight adaptation
- Dispute resolution mechanism

### 🤖 **AI Integration**
- Google Gemini for question rephrasing
- Slang-to-professional translation
- Natural language processing
- Context-aware improvements

### ⚡ **Chainlink Integration**
- Runtime Environment (CRE) workflows
- Automation for settlement
- Decentralized oracle network
- CRON-based scheduling

---

*📚 Return to [Main README](../README.md) for project overview*
