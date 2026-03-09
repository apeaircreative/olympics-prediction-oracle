// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

/**
 * @title IntegrationTest
 * @notice Comprehensive tests covering the full market lifecycle and edge cases
 * @dev Tests the happy path and critical failure modes before Sepolia deployment
 */
contract IntegrationTest is Test {
    PredictionMarket public market;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public owner = address(this);
    address public forwarder = makeAddr("forwarder"); // Mock forwarder
    
    uint256 constant INITIAL_BALANCE = 10 ether;
    
    function setUp() public {
        market = new PredictionMarket(forwarder);
        
        // Fund test accounts
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
        vm.deal(charlie, INITIAL_BALANCE);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Helper to create properly formatted settlement report
    function _createSettlementReport(
        uint256 marketId,
        PredictionMarket.Prediction outcome,
        uint16 confidence
    ) internal pure returns (bytes memory) {
        bytes memory payload = abi.encode(marketId, outcome, confidence);
        return abi.encodePacked(hex"01", payload); // 0x01 prefix triggers _settleMarket
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // INTEGRATION TESTS (Happy Path)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Full lifecycle: Create → Predict → Settle → Claim
    function test_Integration_FullLifecycle_YesWins() public {
        // 1. CREATE MARKET
        vm.prank(alice);
        uint256 marketId = market.createMarket("Will Bitcoin hit $100k in 2026?");
        
        // 2. PREDICTIONS
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(bob);
        market.predict{value: 2 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(charlie);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.No);
        
        // 3. SETTLE (Yes wins, 95% confidence)
        bytes memory settlementData = _createSettlementReport(
            marketId,
            PredictionMarket.Prediction.Yes,
            uint16(9500) // 95%
        );
        
        vm.prank(forwarder); // Must use forwarder, not owner
        market.onReport(hex"", settlementData);
        
        // 4. CLAIM WINNINGS
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        market.claim(marketId);
        uint256 aliceWinnings = alice.balance - aliceBalanceBefore;
        
        // Alice staked 1 ETH out of 3 total in "Yes" pool
        // Total pool: 4 ETH (3 Yes + 1 No)
        // Alice share: 1/3 of 4 ETH = ~1.33 ETH
        assertGt(aliceWinnings, 1 ether, "Alice should profit");
        assertLt(aliceWinnings, 2 ether, "Alice shouldn't get entire pool");
    }
    
    /// @notice Full lifecycle with "No" winning
    function test_Integration_FullLifecycle_NoWins() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Will ETH flip BTC?");
        
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(bob);
        market.predict{value: 3 ether}(marketId, PredictionMarket.Prediction.No);
        
        // Settle: No wins
        bytes memory settlementData = _createSettlementReport(
            marketId,
            PredictionMarket.Prediction.No,
            uint16(8000)
        );
        
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        // Bob claims (should get total pool since he's only "No" better)
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        market.claim(marketId);
        
        assertEq(bob.balance - bobBalanceBefore, 4 ether, "Bob should get entire pool");
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASES: Settlement
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Test settlement with 0% confidence (edge case)
    function test_Settlement_ZeroConfidence() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Uncertain event");
        
        bytes memory settlementData = _createSettlementReport(
            marketId,
            PredictionMarket.Prediction.Yes,
            uint16(0) // 0% confidence
        );
        
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertTrue(m.settled, "Market should settle even with 0% confidence");
        assertEq(m.confidence, 0, "Confidence should be 0");
    }
    
    /// @notice Test settlement with 100% confidence
    function test_Settlement_MaxConfidence() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Certain event");
        
        bytes memory settlementData = _createSettlementReport(
            marketId,
            PredictionMarket.Prediction.No,
            uint16(10000) // 100%
        );
        
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertTrue(m.settled);
        assertEq(m.confidence, 10000);
    }
    
    /// @notice Prevent double settlement
    function test_RevertIf_SettleTwice() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Test market");
        
        bytes memory settlementData = _createSettlementReport(marketId, PredictionMarket.Prediction.Yes, uint16(9000));
        
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        // Try to settle again
        vm.prank(forwarder);
        vm.expectRevert(PredictionMarket.MarketAlreadySettled.selector);
        market.onReport(hex"", settlementData);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASES: Claiming
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Prevent claiming before settlement
    function test_RevertIf_ClaimBeforeSettlement() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Pending market");
        
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.MarketNotSettled.selector);
        market.claim(marketId);
    }
    
    /// @notice Prevent claiming with no stake
    function test_RevertIf_ClaimWithNoStake() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Test market");
        
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        bytes memory settlementData = _createSettlementReport(marketId, PredictionMarket.Prediction.Yes, uint16(9000));
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        // Bob never predicted but tries to claim
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NothingToClaim.selector);
        market.claim(marketId);
    }
    
    /// @notice Prevent double claiming
    function test_RevertIf_ClaimTwice() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Test market");
        
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        bytes memory settlementData = _createSettlementReport(marketId, PredictionMarket.Prediction.Yes, uint16(9000));
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        vm.prank(alice);
        market.claim(marketId);
        
        // Try to claim again
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.AlreadyClaimed.selector);
        market.claim(marketId);
    }
    
    /// @notice Losers get nothing
    function test_Claim_LoserGetsNothing() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Test market");
        
        vm.prank(alice);
        market.predict{value: 1 ether}(marketId, PredictionMarket.Prediction.Yes);
        
        vm.prank(bob);
        market.predict{value: 2 ether}(marketId, PredictionMarket.Prediction.No);
        
        // Yes wins
        bytes memory settlementData = _createSettlementReport(marketId, PredictionMarket.Prediction.Yes, uint16(9000));
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        // Bob (loser) tries to claim - should revert because prediction was wrong
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NothingToClaim.selector);
        market.claim(marketId);
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // STRESS TESTS
    // ═══════════════════════════════════════════════════════════════════════
    
    /// @notice Many predictions on same side
    function test_Stress_ManyPredictors() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Popular market");
        
        // 10 people bet "Yes" (use makeAddr to avoid precompile issues)
        for (uint160 i = 1; i <= 10; i++) {
            address better = makeAddr(string(abi.encodePacked("better", i)));
            vm.deal(better, 1 ether);
            vm.prank(better);
            market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);
        }
        
        bytes memory settlementData = _createSettlementReport(marketId, PredictionMarket.Prediction.Yes, uint16(9000));
        vm.prank(forwarder);
        market.onReport(hex"", settlementData);
        
        // Everyone should be able to claim
        for (uint160 i = 1; i <= 10; i++) {
            address better = makeAddr(string(abi.encodePacked("better", i)));
            vm.prank(better);
            market.claim(marketId);
        }
    }
}
