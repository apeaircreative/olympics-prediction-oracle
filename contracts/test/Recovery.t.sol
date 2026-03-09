// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract RecoveryTest is Test {
    PredictionMarket public market;
    address public forwarder = address(0x123);
    address public creator = address(0xCAFE);
    address public rando = address(0xBAD);
    address public admin; // Test contract is owner

    function setUp() public {
        admin = address(this);
        market = new PredictionMarket(forwarder);
    }

    function test_UpdateQuestion_AsCreator() public {
        // 1. Create Market as 'creator'
        string memory typo = "Who won the 2026 WOrld Cup?";
        vm.prank(creator);
        uint256 id = market.createMarket(typo);

        // 2. Verify Typo Exists
        PredictionMarket.Market memory m = market.getMarket(id);
        assertEq(m.question, typo);

        // 3. Creator fixes typo
        string memory fixedQ = "Who won the 2026 World Cup?";
        vm.prank(creator);
        market.updateQuestion(id, fixedQ);

        // 4. Verify Fix
        m = market.getMarket(id);
        assertEq(m.question, fixedQ);
    }

    function test_UpdateQuestion_AsAdmin() public {
        // 1. Create Market as 'creator'
        string memory typo = "Who won the 2026 WOrld Cup?";
        vm.prank(creator);
        uint256 id = market.createMarket(typo);

        // 2. Admin (this contract) fixes typo
        string memory fixedQ = "Who won the 2026 World Cup?";
        // No prank needed, 'this' is owner
        market.updateQuestion(id, fixedQ);

        // 3. Verify Fix
        PredictionMarket.Market memory m = market.getMarket(id);
        assertEq(m.question, fixedQ);
    }

    function test_RevertIf_UpdateQuestion_AsRando() public {
        // 1. Create Market
        vm.prank(creator);
        uint256 id = market.createMarket("My Question");

        // 2. Rando tries to change it (Should Revert)
        vm.prank(rando);
        vm.expectRevert(PredictionMarket.NotCreatorOrOwner.selector);
        market.updateQuestion(id, "HACKED");
    }

    function test_RevertIf_UpdateQuestion_AfterSettlement() public {
        // 1. Create Market
        vm.prank(creator);
        uint256 id = market.createMarket("Question");

        // 2. Mock Settle
        bytes memory payload = abi.encode(id, PredictionMarket.Prediction.Yes, uint16(100));
        bytes memory report = abi.encodePacked(bytes1(0x01), payload);
        bytes memory metadata = abi.encodePacked(uint256(32), bytes32(0), bytes10(0), address(0));

        // Call onReport as forwarder
        vm.prank(forwarder);
        market.onReport(metadata, report);

        // 3. Try to update after settlement (Should Revert)
        vm.prank(creator);
        vm.expectRevert(PredictionMarket.MarketAlreadySettled.selector);
        market.updateQuestion(id, "New Question");
    }
}
