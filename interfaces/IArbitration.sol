// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IArbitration
 * @dev Interface for the complete arbitration system including dispute management,
 * evidence handling, and voting processes
 * 
 * Combines functionality for:
 * - Dispute management and tracking
 * - Evidence submission and retrieval
 * - Arbitrator voting and result calculation
 */

interface IArbitration {
    enum DisputeStatus {
        PENDING,
        VOTING,
        RESOLVED,
        APPEALED
    }

    // Dispute Events
    event DisputeCreated(bytes32 indexed disputeId, address initiator, address respondent);
    event DisputeResolved(bytes32 indexed disputeId, uint8 resolution);
    event ArbitratorVoted(bytes32 indexed disputeId, address arbitrator);
    event DisputeAppealed(bytes32 indexed disputeId);
    
    // Evidence Events
    event EvidenceSubmitted(bytes32 indexed disputeId, address submitter, bytes32 evidenceHash);
    
    // Voting Events
    event VoteSubmitted(bytes32 indexed disputeId, address arbitrator);
    event VotingClosed(bytes32 indexed disputeId, uint8 result);

    // Dispute Management Functions
    function createDispute(
        address initiator,
        address respondent,
        uint256 amount
    ) external returns (bytes32 disputeId);

    function resolveDispute(bytes32 disputeId) external;
    function appealDispute(bytes32 disputeId) external;
    function getDisputeStatus(bytes32 disputeId) external view returns (DisputeStatus);
    
    // Evidence Management Functions
    function submitEvidence(
        bytes32 disputeId,
        bytes32 evidenceHash,
        string calldata evidenceType,
        string calldata metadataURI
    ) external;

    function getEvidence(bytes32 disputeId) 
        external 
        view 
        returns (
            bytes32[] memory hashes,
            address[] memory submitters,
            string[] memory evidenceTypes,
            string[] memory metadataURIs
        );

    // Voting Functions
    function submitVote(
        bytes32 disputeId,
        uint8 decision,
        string calldata justification
    ) external;

    function getVotingResult(bytes32 disputeId) 
        external 
        view 
        returns (
            uint8 decision,
            uint256 totalVotes,
            bool isComplete
        );

    function getArbitratorPerformance(address arbitrator) 
        external 
        view 
        returns (
            uint256 casesHandled,
            uint256 averageResolutionTime,
            uint256 appealRate
        );
}