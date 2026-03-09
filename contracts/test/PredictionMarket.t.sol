// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract PredictionMarketTest is Test {
    PredictionMarket public market;
    address public forwarder = address(0x123);
    address public owner = address(0x789);
    address public user = address(0x456);
    address public oracle = address(0xABC);

    function setUp() public {
        vm.prank(owner);
        market = new PredictionMarket(forwarder);
    }

    // ================================================================
    //                      CORE UNIT TESTS
    // ================================================================

    function testCreateMarket() public {
        vm.prank(owner);
        
        uint256 marketId = market.createMarket(
            "Will Ilia Malinin win gold at 2026 Olympics?"
        );

        assertEq(marketId, 0, "First market should have ID 0");
        
        // Create second market to test ID increment
        vm.prank(owner);
        uint256 marketId2 = market.createMarket(
            "Will Yuma Kagiyama win silver?"
        );
        
        assertEq(marketId2, 1, "Second market should have ID 1");
        
        // Get market details (returns struct, not tuple)
        PredictionMarket.Market memory marketData = market.getMarket(marketId);
        assertEq(marketData.question, "Will Ilia Malinin win gold at 2026 Olympics?");
        assertTrue(marketData.endTime > block.timestamp, "End time should be in future");
    }

    function testPlaceBet() public {
        // Create market
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        // Place bet
        vm.deal(user, 1 ether);
        vm.prank(user);
        market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);

        // Verify bet
        PredictionMarket.UserPrediction memory prediction = market.getPrediction(marketId, user);
        assertEq(prediction.amount, 0.1 ether);
        assertEq(uint256(prediction.prediction), uint256(PredictionMarket.Prediction.Yes));
    }

    function testSettleMarket() public {
        // Create market
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        // Place bets
        vm.deal(user, 1 ether);
        vm.prank(user);
        market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);

        // Fast forward time
        vm.warp(block.timestamp + 8 days);

        // Settle market via triggerSettlement (Chainlink Automation compatible)
        vm.prank(oracle);
        market.triggerSettlement(marketId);

        // Verify settlement
        PredictionMarket.Market memory marketData = market.getMarket(marketId);
        assertTrue(marketData.settled, "Market should be settled");
        assertTrue(marketData.outcome == PredictionMarket.Prediction.Yes, "Outcome should be true");
    }

    function testClaimReward() public {
        // Create and settle market
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        vm.deal(user, 1 ether);
        vm.prank(user);
        market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);

        vm.warp(block.timestamp + 8 days);
        
        vm.prank(oracle);
        market.triggerSettlement(marketId);

        // Claim reward
        uint256 balanceBefore = user.balance;
        vm.prank(user);
        market.claim(marketId);

        // Verify reward claimed
        uint256 balanceAfter = user.balance;
        assertTrue(balanceAfter > balanceBefore, "User should receive reward");
    }

    function testOnlyOwnerCanCreateMarket() public {
        vm.prank(user);
        vm.expectRevert();
        market.createMarket("Test market");
    }

    function testOnlyOracleCanSettle() public {
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        vm.prank(user);
        vm.expectRevert();
        market.triggerSettlement(marketId);
    }

    function testInvalidBetAmount() public {
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        vm.prank(user);
        vm.expectRevert(PredictionMarket.InvalidAmount.selector);
        market.predict{value: 0}(marketId, PredictionMarket.Prediction.Yes);
    }

    function testCannotBetAfterEndTime() public {
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        // Fast forward past end time (7 days + 1 day)
        vm.warp(block.timestamp + 8 days);

        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert();
        market.predict{value: 0.1 ether}(marketId, PredictionMarket.Prediction.Yes);
    }

    function testCannotSettleBeforeEndTime() public {
        vm.prank(owner);
        uint256 marketId = market.createMarket("Test market");

        vm.prank(oracle);
        vm.expectRevert();
        market.triggerSettlement(marketId);
    }

    // ================================================================
    //                      FUZZ TESTS
    // ================================================================

    function testFuzz_CreateMarket_StringLength(string memory question) public {
        uint256 len = bytes(question).length;
        vm.assume(len > 0 && len < 200); // Reasonable bounds

        uint256 startGas = gasleft();
        vm.prank(owner);
        market.createMarket(question);
        uint256 gasUsed = startGas - gasleft();

        console.log("FUZZ_DATA_STRING_LENGTH:", len, gasUsed);
    }

    function testFuzz_Predict_Amount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100 ether); // Reasonable bounds
        
        string memory q = "Will this fuzzing work?";
        vm.prank(owner);
        uint256 marketId = market.createMarket(q);

        vm.deal(user, amount);
        vm.prank(user);
        market.predict{value: amount}(marketId, PredictionMarket.Prediction.Yes);
        
        PredictionMarket.UserPrediction memory userPred = market.getPrediction(marketId, user);
        assertEq(userPred.amount, amount);
    }

    function testFuzz_CreateMarket_Content(string memory question) public {
        vm.assume(bytes(question).length > 0 && bytes(question).length < 200);
        
        vm.prank(owner);
        market.createMarket(question);
    }
}
