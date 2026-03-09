# Chainlink Automation Upgrade

For production, replace CRON bot with Chainlink Automation:

1. **Deploy Contract with Upkeep Function:**
   ```solidity
   function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
       // Check for unsettled markets past endTime
       return (hasUnsettledMarkets(), "");
   }

   function performUpkeep(bytes calldata) external {
       // Trigger settlement for due markets
       settleDueMarkets();
   }
   ```

2. **Register Upkeep:** On Chainlink Automation, fund with LINK, set trigger.

3. **Benefits:** Decentralized, gas-efficient, no server needed.

Current bot is great demo—upgrade to Automation for real deployment!
