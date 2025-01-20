// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IReputation
 * @dev Interface for managing reputation scores in the work agreement system
 * 
 * This interface defines the core functionality for tracking and managing
 * reputation scores for both workers and employers. It supports:
 * 
 * SCORING SYSTEM:
 * - Overall reputation scores (0-100)
 * - Multiple scoring factors (completion, timeliness, etc.)
 * - Dispute impact tracking
 * - Stake-based reputation weighting
 * 
 * PRIVACY FEATURES:
 * - Optional score privacy
 * - Selective disclosure
 * - Minimum threshold proofs
 * - History anonymization
 * 
 * RECOVERY MECHANISMS:
 * - Score rehabilitation
 * - Dispute resolution impact
 * - Performance improvement tracking
 * 
 * INTEGRATION POINTS:
 * - WorkContract: Performance updates
 * - ArbitrationSystem: Dispute handling
 * - DAOs: Governance and oversight
 * - ZKP Verifier: Privacy preservation
 *
 * @notice This system aims to provide fair, transparent, and privacy-preserving
 * reputation tracking while allowing for score recovery and improvement
 */

interface IReputation {
    enum ReputationType {
        WORKER,
        EMPLOYER
    }

    enum ScoreFactors {
        COMPLETION,      // Work/contract completion
        TIMELINESS,     // Meeting deadlines
        COMMUNICATION,  // Response and clarity
        QUALITY,        // Work/management quality
        PAYMENT,        // Payment reliability
        FAIRNESS       // Fair treatment/working conditions
    }

    event ScoreUpdated(
        address indexed entity,
        ReputationType entityType,
        uint256 newScore,
        ScoreFactors factor
    );
    
    event DisputeImpact(
        address indexed entity,
        ReputationType entityType,
        int256 scoreChange
    );

    event StakeDeposited(
        address indexed entity,
        ReputationType entityType,
        uint256 amount
    );

    function updateScore(
        address entity,
        ReputationType entityType,
        ScoreFactors factor,
        uint256 score,
        bytes calldata proof
    ) external;

    function handleDisputeOutcome(
        address entity,
        ReputationType entityType,
        bool won
    ) external;

    function depositStake() external payable;

    function getScore(address entity, ReputationType entityType) 
        external 
        view 
        returns (uint256 score);

    function getDetailedScore(address entity, ReputationType entityType)
        external
        view
        returns (
            uint256 overallScore,
            uint256 completionScore,
            uint256 timelinessScore,
            uint256 communicationScore,
            uint256 qualityScore,
            uint256 paymentScore,
            uint256 fairnessScore,
            uint256 totalContracts,
            uint256 disputeCount
        );
}