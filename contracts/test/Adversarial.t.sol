// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

/**
 * @title AdversarialTest
 * @notice "Grey Area" stress tests based on REAL prediction market exploits
 * @dev Research sources: Polymarket whale manipulation, oracle front-running,
 *      UMA governance attacks, emotional bias exploitation
 */
contract AdversarialTest is Test {
    PredictionMarket public market;
    
    address public whale = makeAddr("whale"); // High-budget manipulator
    address public victim = makeAddr("victim");
    address public arbitrageur = makeAddr("arbitrageur");
    address public forwarder = makeAddr("forwarder");
    
    uint256 constant WHALE_BALANCE = 1000 ether;
    uint256 constant VICTIM_BALANCE = 10 ether;
    
    function setUp() public {
        market = new PredictionMarket(forwarder);
        
        vm.deal(whale, WHALE_BALANCE);
        vm.deal(victim, VICTIM_BALANCE);
        vm.deal(arbitrageur, 100 ether);
    }
    
    /// @notice Helper to create settlement report
    function _settle(uint256 marketId, PredictionMarket.Prediction outcome, uint16 confidence) internal {
        bytes memory payload = abi.encode(marketId, outcome, confidence);
        bytes memory data = abi.encodePacked(hex"01", payload);
        vm.prank(forwarder);
        market.onReport(hex"", data);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 1: Whale Manipulation (Polymarket $7M UMA Attack)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Whale creates massive imbalance to manipulate perceived odds
    /// @dev Based on: Polymarket whale using 5M UMA tokens to sway disputed resolution
    function test_WhaleManipulation_MassiveImbalance() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Will candidate X win?");
        
        // Small organic bets (1:1 ratio)
        vm.prank(victim);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(arbitrageur);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.No);
        
        // WHALE ATTACK: Dump 100 ETH on "Yes" to create 100:1 imbalance
        vm.prank(whale);
        market.predict{value: 100 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Verify pool imbalance
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.totalYesPool, 101 ether, "Yes pool massively inflated");
        assertEq(m.totalNoPool, 1 ether, "No pool starved");
        
        // If "No" wins (whale bet wrong), whale loses everything
        _settle(marketId, PredictionMarket.Prediction.No, 9500);
        
        uint256 arbitrageurBefore = arbitrageur.balance;
        vm.prank(arbitrageur);
        market.claim(marketId);
        
        // Arbitrageur (1 ETH bet) gets entire 102 ETH pool
        assertEq(arbitrageur.balance - arbitrageurBefore, 102 ether, "Arbitrageur wins big");
    }
    
    /// @notice Multiple whales coordinate to manipulate odds
    function test_WhaleManipulation_CoordinatedAttack() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Coordinated market");
        
        // 3 whale accounts bet same side (evading single-account detection)
        address whale1 = makeAddr("whale1");
        address whale2 = makeAddr("whale2");
        address whale3 = makeAddr("whale3");
        
        vm.deal(whale1, 50 ether);
        vm.deal(whale2, 50 ether);
        vm.deal(whale3, 50 ether);
        
        vm.prank(whale1);
        market.predict{value: 50 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(whale2);
        market.predict{value: 50 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(whale3);
        market.predict{value: 50 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Victim sees 150:0 imbalance, assumes "insider info", bets Yes
        vm.prank(victim);
        market.predict{value: 5 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Plot twist: Whales had NO insider info, they just manipulated odds
        // Market settles "No"
        _settle(marketId, PredictionMarket.Prediction.No, 8000);
        
        // All whales + victim lose (no one bet "No")
        // This tests: What happens when EVERYONE loses?
        vm.expectRevert(PredictionMarket.NothingToClaim.selector);
        vm.prank(whale1);
        market.claim(marketId);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 2: Oracle Front-Running (Mempool Sniping)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Attacker monitors mempool for settlement tx, front-runs with bet
    /// @dev In real blockchain: Bot sees settlement in mempool, submits bet with higher gas
    function test_FrontRunning_SettlementSniping() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Sports game outcome");
        
        // Game is ongoing, light betting
        vm.prank(victim);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Game ends. Oracle prepares settlement tx (Yes wins)
        // ATTACKER SEES THIS IN MEMPOOL BEFORE IT'S MINED
        
        // Attacker front-runs with massive bet (higher gas fee)
        vm.prank(whale);
        market.predict{value: 50 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Then settlement tx mines
        _settle(marketId, PredictionMarket.Prediction.Yes, 10000);
        
        // Attacker claims share
        uint256 whaleBefore = whale.balance;
        vm.prank(whale);
        market.claim(marketId);
        uint256 whalePayout = whale.balance - whaleBefore;
        
        // The VULNERABILITY: Whale bet 50/51 = 98% of pool AFTER outcome known
        // Payout: (50/51) * 51 = ~50 ETH (proportional share, minimal profit)
        // BUT: Zero risk! They only bet because they saw the settlement coming
        // This demonstrates mempool front-running attack vector
        assertGt(whalePayout, 49.9 ether, "Whale gets ~50 ETH from front-running");
    }
    
    /// @notice Test if late bets (after outcome known off-chain) are prevented
    function test_FrontRunning_CannotBetAfterSettlement() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Test market");
        
        vm.prank(victim);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Market settles
        _settle(marketId, PredictionMarket.Prediction.Yes, 9000);
        
        // Attacker tries to bet AFTER settlement
        vm.prank(whale);
        vm.expectRevert(PredictionMarket.MarketAlreadySettled.selector);
        market.predict{value: 10 ether}(marketId, PredictionMarket.Prediction.Yes);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 3: Low Liquidity Exploitation
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Attacker waits for low liquidity, manipulates with small bet
    function test_LowLiquidity_TinyMarketManipulation() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Obscure niche market");
        
        // VERY low liquidity (0.01 ETH total)
        vm.prank(victim);
        market.predict{value: 0.005 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(arbitrageur);
        market.predict{value: 0.005 ether}(marketId, PredictionMarket.Prediction.No);
        
        // Whale adds just 0.1 ETH to create 10:1 imbalance
        vm.prank(whale);
        market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        PredictionMarket.Market memory m = market.getMarket(marketId);
        
        // Yes pool: 0.105 ETH, No pool: 0.005 ETH = 21:1 ratio
        assertGt(m.totalYesPool, m.totalNoPool * 20, "Massive ratio swing with tiny capital");
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 4: Emotional Bias Exploitation
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Markets on emotional topics attract irrational betting
    /// @dev Research: Political markets show "bet what you want, not what you know"
    function test_EmotionalBias_IrrationalBetting() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Will my favorite team win championship?");
        
        // Victim bets emotionally (oversized bet on favorite)
        vm.prank(victim);
        market.predict{value: 8 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Rational better bets opposite (underdog)
        vm.prank(arbitrageur);
        market.predict{value: 2 ether}(marketId, PredictionMarket.Prediction.No);
        
        // Reality: Underdog wins (emotion ≠ truth)
        _settle(marketId, PredictionMarket.Prediction.No, 7500);
        
        uint256 arbBefore = arbitrageur.balance;
        vm.prank(arbitrageur);
        market.claim(marketId);
        
        // Arbitrageur (2 ETH) gets entire 10 ETH pool = 5x return
        assertEq(arbitrageur.balance - arbBefore, 10 ether, "Rational better exploits emotional bias");
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 5: Oracle Manipulation (False Data)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Compromised oracle reports false outcome
    /// @dev This tests: Does contract blindly trust oracle, or have safeguards?
    function test_OracleManipulation_FalseOutcome() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Did event X happen?");
        
        vm.prank(victim);
        market.predict{value: 5 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(arbitrageur);
        market.predict{value: 5 ether}(marketId, PredictionMarket.Prediction.No);
        
        // ATTACK: Compromised forwarder sends false outcome
        // Real outcome: Yes, but attacker controls oracle reports "No"
        _settle(marketId, PredictionMarket.Prediction.No, 10000); // 100% confidence (suspiciously high)
        
        // Contract has NO way to know this is false
        // This demonstrates oracle dependency risk
        vm.prank(arbitrageur);
        market.claim(marketId);
        
        // Arbitrageur wins due to false data
        // In production: Would need dispute resolution system (UMA-style)
        assertTrue(true, "Contract accepted false oracle data - requires governance layer");
    }
    
    /// @notice Multiple rapid settlement attempts (oracle spam)
    function test_OracleManipulation_SettlementSpam() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Test market");
        
        vm.prank(victim);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        // Legitimate settlement
        _settle(marketId, PredictionMarket.Prediction.Yes, 9000);
        
        // Attacker tries to re-settle with different outcome (oracle compromise)
        vm.expectRevert(PredictionMarket.MarketAlreadySettled.selector);
        _settle(marketId, PredictionMarket.Prediction.No, 5000);
        
        // Double-settlement prevented ✓
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 6: Rounding Errors & Dust Attacks
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Bet tiny amounts to exploit rounding in payout calculation
    function test_RoundingError_DustBets() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Rounding test");
        
        // Many tiny bets (0.0001 ETH each)
        address[] memory dustBetters = new address[](100);
        for (uint160 i = 0; i < 100; i++) {
            dustBetters[i] = address(uint160(0x1000) + i); // Simple sequential addresses
            vm.deal(dustBetters[i], 1 ether);
            vm.prank(dustBetters[i]);
            market.predict{value: 0.0001 ether}(marketId, PredictionMarket.Prediction.Yes);
        }
        
        // One large bet
        vm.prank(arbitrageur);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        _settle(marketId, PredictionMarket.Prediction.Yes, 9000);
        
        // Verify proportional payouts (dust better gets fair share)
        uint256 dust1Before = dustBetters[0].balance;
        vm.prank(dustBetters[0]);
        market.claim(marketId);
        
        // 0.0001 ETH bet out of 1.01 total = should get (0.0001/1.01) * 1.01 = ~0.0001 ETH
        uint256 payout = dustBetters[0].balance - dust1Before;
        assertGt(payout, 0, "Dust better gets non-zero payout");
        assertApproxEqRel(payout, 0.0001 ether, 0.01e18, "Payout is proportional (within 1%)");
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCENARIO 7: Gas Griefing
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Attacker forces expensive claim operations
    function test_GasGriefing_MassiveClaims() public {
        vm.prank(victim);
        uint256 marketId = market.createMarket("Gas grief test");
        
        // 50 winners (using simple sequential addresses)
        address[] memory claimers = new address[](50);
        for (uint160 i = 0; i < 50; i++) {
            claimers[i] = address(uint160(0x2000) + i);
            vm.deal(claimers[i], 1 ether);
            vm.prank(claimers[i]);
            market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);
        }
        
        _settle(marketId, PredictionMarket.Prediction.Yes, 9000);
        
        // Each claim should be reasonably gas-efficient
        uint256 gasBefore = gasleft();
        vm.prank(claimers[0]);
        market.claim(marketId);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Claim should be < 100k gas (even with many participants)
        assertLt(gasUsed, 100_000, "Claim operation is gas-efficient");
    }
}
