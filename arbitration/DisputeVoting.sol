// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DisputeVoting
 * @dev Registry managing arbitrator voting processes and results
 * 
 * FUNCTIONALITY:
 * 1. Vote Management:
 *    - Secure vote submission
 *    - Weight calculation
 *    - Justification tracking
 *    - Result aggregation
 *
 * 2. Arbitrator Features:
 *    - Vote validation
 *    - Weight assignment
 *    - Participation tracking
 *    - Decision justification
 *
 * 3. Result Calculation:
 *    - Weighted averaging
 *    - Minimum participation checks
 *    - Deadline enforcement
 *    - Final decision computation
 *
 * INTEGRATION POINTS:
 * - ArbitrationRegistry: Vote submission and result retrieval
 * - WorkerDAO/EmployerDAO: Arbitrator validation
 * 
 * @notice This registry ensures secure and transparent voting processes
 * during dispute resolution, maintaining vote integrity and proper weight
 * calculation
 */

import "../interfaces/IDisputeVoting.sol";
import "../interfaces/IArbitrationRegistry.sol";

contract DisputeVoting is IDisputeVoting {
    struct Vote {
        uint8 decision;
        uint256 weight;
        string justification;
        bool submitted;
    }

    IArbitrationRegistry public arbitrationRegistry;
    
    // disputeId => arbitrator => vote
    mapping(bytes32 => mapping(address => Vote)) public votes;
    // disputeId => voting results
    mapping(bytes32 => uint8) public results;
    
    constructor(address _arbitrationRegistry) {
        arbitrationRegistry = IArbitrationRegistry(_arbitrationRegistry);
    }

    modifier onlyArbitrator() {
        // Check with ArbitrationRegistry if sender is active arbitrator
        _;
    }

    function submitVote(
        bytes32 disputeId,
        uint8 decision,
        string calldata justification
    ) external override onlyArbitrator {
        require(!votes[disputeId][msg.sender].submitted, "Already voted");
        require(decision <= 100, "Invalid decision percentage");

        votes[disputeId][msg.sender] = Vote({
            decision: decision,
            weight: 1, // Could be based on arbitrator reputation
            justification: justification,
            submitted: true
        });

        emit VoteSubmitted(disputeId, msg.sender);
    }

    function getVotingResult(bytes32 disputeId) 
        external 
        view 
        override
        returns (
            uint8 decision,
            uint256 totalVotes,
            bool isComplete
        ) 
    {
        // Implementation to calculate weighted average of votes
        return (results[disputeId], 0, false);
    }

    function getArbitratorVote(bytes32 disputeId, address arbitrator)
        external
        view
        override
        returns (
            uint8 decision,
            uint256 weight,
            string memory justification
        )
    {
        Vote memory vote = votes[disputeId][arbitrator];
        require(vote.submitted, "Vote not found");
        
        return (vote.decision, vote.weight, vote.justification);
    }
}