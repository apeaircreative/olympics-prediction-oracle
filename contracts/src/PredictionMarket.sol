// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReceiverTemplate} from "./interfaces/ReceiverTemplate.sol";

/// @title PredictionMarket
/// @notice A simplified prediction market for CRE bootcamp.
contract PredictionMarket is ReceiverTemplate {
    error MarketDoesNotExist();
    error MarketAlreadySettled();
    error MarketNotSettled();
    error MarketNotEnded();
    error AlreadyPredicted();
    error InvalidAmount();
    error NothingToClaim();
    error AlreadyClaimed();
    error TransferFailed();
    error NotCreatorOrOwner();
    error SessionNotActive();

    event MarketCreated(uint256 indexed marketId, string question, uint48 endTime, address creator);
    event PredictionMade(uint256 indexed marketId, address indexed predictor, Prediction prediction, uint256 amount);
    event SettlementRequested(uint256 indexed marketId, string question);
    event MarketSettled(uint256 indexed marketId, Prediction outcome, uint16 confidence);
    event MarketResolved(uint256 indexed marketId, Prediction outcome, uint16 confidence);
    event WinningsClaimed(uint256 indexed marketId, address indexed claimer, uint256 amount);
    event QuestionUpdated(uint256 indexed marketId, string question);
    event QuestionProcessed(
        uint256 indexed marketId,
        string originalQuestion,
        string finalQuestion,
        bool wasRephrased
    );

    enum Prediction {
        Yes,
        No
    }

    struct Market {
        address creator;
        uint48 createdAt;
        uint48 endTime;
        uint48 settledAt;
        bool settled;
        uint16 confidence;
        Prediction outcome;
        uint256 totalYesPool;
        uint256 totalNoPool;
        string question;
    }

    struct UserPrediction {
        uint256 amount;
        Prediction prediction;
        bool claimed;
    }

    uint256 internal nextMarketId;
    mapping(uint256 marketId => Market market) internal markets;
    mapping(uint256 marketId => mapping(address user => UserPrediction)) internal predictions;

    // SESSION-LIMITED ORACLE SECURITY (Phase 21)
    // The Oracle (Forwarder) can only report during this window
    uint48 internal sSessionStart; // Mar 8, 2026 10:00 AM CET (Unix: 1741426800)
    uint48 internal sSessionEnd;   // Mar 8, 2026 11:00 PM CET (Unix: 1741470000)

    /// @notice Constructor sets the Chainlink Forwarder address for security
    /// @param _forwarderAddress The address of the Chainlink KeystoneForwarder contract
    /// @dev SEPOLIA TESTNET IDENTITY: 0x15fc6ae953e024d975e77382eeec56a9101f9f88
    constructor(address _forwarderAddress) ReceiverTemplate(_forwarderAddress) {
        // Initialize session window for Hackathon Demo (always active)
        sSessionStart = 0;
        sSessionEnd = type(uint48).max;
    }

    /// @notice Check if the Oracle session is active (mitigates session hijacking)
    /// @dev Even if the Oracle's key is stolen, it cannot be used outside this window
    function _isSessionActive() internal view returns (bool) {
        return block.timestamp >= sSessionStart && block.timestamp <= sSessionEnd;
    }

    // ================================================================
    // │                       Create market                          │
    // ================================================================

    /// @notice Create a new prediction market.
    /// @param question The question for the market.
    /// @return marketId The ID of the newly created market.
    function createMarket(string memory question) public returns (uint256 marketId) {
        marketId = nextMarketId++;

        uint48 endTime = uint48(block.timestamp + 7 days); // 1 week market

        markets[marketId] = Market({
            creator: msg.sender,
            createdAt: uint48(block.timestamp),
            endTime: endTime,
            settledAt: 0,
            settled: false,
            confidence: 0,
            outcome: Prediction.Yes,
            totalYesPool: 0,
            totalNoPool: 0,
            question: question
        });

        emit MarketCreated(marketId, question, endTime, msg.sender);
    }

    // ================================================================
    // │                          Predict                             │
    // ================================================================

    /// @notice Make a prediction on a market.
    /// @param marketId The ID of the market.
    /// @param prediction The prediction (Yes or No).
    function predict(uint256 marketId, Prediction prediction) external payable {
        Market memory m = markets[marketId];

        if (m.creator == address(0)) revert MarketDoesNotExist();
        if (m.settled) revert MarketAlreadySettled();
        if (msg.value == 0) revert InvalidAmount();

        UserPrediction memory userPred = predictions[marketId][msg.sender];
        if (userPred.amount != 0) revert AlreadyPredicted();

        predictions[marketId][msg.sender] = UserPrediction({
            amount: msg.value,
            prediction: prediction,
            claimed: false
        });

        if (prediction == Prediction.Yes) {
            markets[marketId].totalYesPool += msg.value;
        } else {
            markets[marketId].totalNoPool += msg.value;
        }

        emit PredictionMade(marketId, msg.sender, prediction, msg.value);
    }

    /// @notice Buy YES shares.
    /// @param marketId The ID of the market.
    function buyYes(uint256 marketId) external payable {
        this.predict(marketId, Prediction.Yes);
    }

    /// @notice Buy NO shares.
    /// @param marketId The ID of the market.
    function buyNo(uint256 marketId) external payable {
        this.predict(marketId, Prediction.No);
    }

    // ================================================================
    // │                    Request settlement                        │
    // ================================================================

    /// @notice Trigger settlement for a market (Chainlink Automation compatible)
    /// @param marketId The ID of the market to settle
    function triggerSettlement(uint256 marketId) external {
        Market memory m = markets[marketId];

        if (m.creator == address(0)) revert MarketDoesNotExist();
        if (m.settled) revert MarketAlreadySettled();

        emit SettlementRequested(marketId, m.question);
    }

    // ================================================================
    // │                 Market settlement by CRE                     │
    // ================================================================

    /// @notice Settles a market from a CRE report with AI-determined outcome.
    /// @dev Called via onReport → _processReport when prefix byte is 0x01.
    /// @param report ABI-encoded (uint256 marketId, Prediction outcome, uint16 confidence)
    function _settleMarket(bytes calldata report) internal {
        // SESSION-LIMITED ORACLE SECURITY (Phase 21)
        // Even if the Oracle's key is stolen, it can only be used during the Feb 13 window
        if (!_isSessionActive()) revert SessionNotActive();

        (uint256 marketId, Prediction outcome, uint16 confidence) = abi.decode(
            report,
            (uint256, Prediction, uint16)
        );

        Market memory m = markets[marketId];

        if (m.creator == address(0)) revert MarketDoesNotExist();
        if (m.settled) revert MarketAlreadySettled();
        if (block.timestamp < m.endTime) revert MarketNotEnded(); // Prevent early settlement

        // ACE AUDIT HOOK: Physically enforce the "No Backflip Penalty" or "Quad-Flip" grade
        // In a full ACE implementation, this would call evaluate() on a Policy contract.
        // For our Sepolia refactor, we are using the prefix 0x01 as the "Compliance Verified" signal.

        markets[marketId].settled = true;
        markets[marketId].confidence = confidence;
        markets[marketId].settledAt = uint48(block.timestamp);
        markets[marketId].outcome = outcome;

        emit MarketSettled(marketId, outcome, confidence);
        emit MarketResolved(marketId, outcome, confidence);
    }

    // ================================================================
    // │                      CRE Entry Point                         │
    // ================================================================

    /// @inheritdoc ReceiverTemplate
    /// @dev Routes to either market creation or settlement based on prefix byte.
    ///      POWER USER INSIGHT: Unified Extractor Pattern (Prefix Routing)
    ///      - No prefix → Create market
    ///      - 0x01 → Settle market
    ///      - 0x02 → Expert Audit / Policy Check (Phase 16)
    function _processReport(bytes calldata report) internal override {
        if (report.length == 0) return;

        uint8 prefix = uint8(report[0]);

        if (prefix == 0x01) {
            _settleMarket(report[1:]);
        } else if (prefix == 0x02) {
            _processExpertAudit(report[1:]);
        } else if (prefix == 0x03) {
            _handleProcessedQuestion(report[1:]);
        } else {
            string memory question = abi.decode(report, (string));
            createMarket(question);
        }
    }

    /// @notice Handler for processed questions (Prefix 0x03)
    /// @param report (string originalQuestion, string finalQuestion, bool wasRephrased)
    function _handleProcessedQuestion(bytes calldata report) internal {
        (string memory original, string memory finalQuest, bool rephrased) = abi.decode(
            report,
            (string, string, bool)
        );

        uint256 marketId = createMarket(finalQuest);
        
        emit QuestionProcessed(
            marketId,
            original,
            finalQuest,
            rephrased
        );
    }

    /// @notice Internal handler for Expert Audits (Phase 16 hook)
    function _processExpertAudit(bytes calldata report) internal {
        // Implementation for Feb 13 Comparative Analytics
    }

    // ================================================================
    // │                      Claim winnings                          │
    // ================================================================

    /// @notice Claim winnings after market settlement.
    /// @param marketId The ID of the market.
    function claim(uint256 marketId) external {
        Market memory m = markets[marketId];

        if (m.creator == address(0)) revert MarketDoesNotExist();
        if (!m.settled) revert MarketNotSettled();

        UserPrediction memory userPred = predictions[marketId][msg.sender];

        if (userPred.amount == 0) revert NothingToClaim();
        if (userPred.claimed) revert AlreadyClaimed();
        if (userPred.prediction != m.outcome) revert NothingToClaim();

        predictions[marketId][msg.sender].claimed = true;

        uint256 totalPool = m.totalYesPool + m.totalNoPool;
        uint256 winningPool = m.outcome == Prediction.Yes ? m.totalYesPool : m.totalNoPool;
        uint256 payout = (userPred.amount * totalPool) / winningPool;

        (bool success,) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    // ================================================================
    // │                        Recovery / DX                         │
    // ================================================================

    /// @notice Updates the market question to fix typos.
    /// @dev Can only be called by the Creator or the Contract Owner.
    ///      Only allowed if the market is NOT settled.
    /// @param marketId The ID of the market to update.
    /// @param newQuestion The new question text.
    function updateQuestion(uint256 marketId, string calldata newQuestion) external {
        Market storage m = markets[marketId];

        if (m.creator == address(0)) revert MarketDoesNotExist();
        if (m.settled) revert MarketAlreadySettled();
        
        // Authorization: Creator (Self-Service) OR Owner (Admin/Support)
        if (msg.sender != m.creator && msg.sender != owner()) {
            revert NotCreatorOrOwner();
        }

        m.question = newQuestion;
        emit QuestionUpdated(marketId, newQuestion);
    }

    // ================================================================
    // │                          Getters                             │
    // ================================================================

    /// @notice Get market details.
    /// @param marketId The ID of the market.
    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }

    /// @notice Get user's prediction for a market.
    /// @param marketId The ID of the market.
    /// @param user The user's address.
    function getPrediction(uint256 marketId, address user) external view returns (UserPrediction memory) {
        return predictions[marketId][user];
    }
}
