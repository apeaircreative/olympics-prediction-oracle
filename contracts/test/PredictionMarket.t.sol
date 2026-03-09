// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract PredictionMarketTest is Test {
    PredictionMarket public market;
    address public forwarder = address(0x123);
    address public user = address(0x456);

    function setUp() public {
        market = new PredictionMarket(forwarder);
    }

    // ================================================================
    // │                  FUZZ TEST 1: String Length                  │
    // ================================================================
    // Foundry will generate random strings 's' of varying lengths.
    // Goal: Find the gas limit breaking point.
    function testFuzz_CreateMarket_StringLength(string memory question) public {
        // We define a reasonable max length for "Happy Path" (e.g., 200 chars)
        // But we want to fail if it exceeds the block limit, which it won't easily on Anvil.
        // We log the length to analyze gas usage.
        
        uint256 len = bytes(question).length;
        vm.assume(len > 0); // Skip empty string (handled by logic?) logic doesn't strictly check empty string in createMarket yet!

        uint256 startGas = gasleft();
        market.createMarket(question);
        uint256 gasUsed = startGas - gasleft();

        // Emit log for "Quantum" analysis
        // Length | Gas Used
        console.log("FUZZ_DATA_STRING_LENGTH:", len, gasUsed);
    }

    // ================================================================
    // │                  FUZZ TEST 2: Payment Amounts                │
    // ================================================================
    function testFuzz_Predict_Amount(uint256 amount) public {
        string memory q = "Will this fuzzing work?";
        uint256 marketId = market.createMarket(q);

        vm.deal(user, amount);
        vm.prank(user);

        if (amount == 0) {
            // Should revert
            vm.expectRevert(PredictionMarket.InvalidAmount.selector);
            market.predict{value: amount}(marketId, PredictionMarket.Prediction.Yes);
        } else {
            // Should succeed
            market.predict{value: amount}(marketId, PredictionMarket.Prediction.Yes);
            
            // Verify state
            PredictionMarket.UserPrediction memory userPred = market.getPrediction(marketId, user);
            assertEq(userPred.amount, amount);
        }
    }

    // ================================================================
    // │                  FUZZ TEST 3: UTF-8 / Weird Chars            │
    // ================================================================
    // This overlaps with string length but focuses on content.
    // Solidity strings are UTF-8 compliant but "dumb" bytes.
    function testFuzz_CreateMarket_Content(string memory question) public {
        // Just verify it doesn't revert for weird chars
        market.createMarket(question);
    }
}
