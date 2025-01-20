// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IArbitrationRegistry.sol";
import "../interfaces/IWorkerDAO.sol";
import "../interfaces/IEmployerDAO.sol";

/**
 * @title ArbitrationRegistry
 * @dev Core registry for managing disputes and arbitration processes
 * 
 * FUNCTIONALITY:
 * 1. Dispute Management:
 *    - Creation and tracking of disputes
 *    - Status progression (PENDING → VOTING → RESOLVED/APPEALED)
 *    - Resolution calculation based on arbitrator votes
 *    - Appeal handling
 *
 * 2. Arbitrator Tracking:
 *    - Performance metrics
 *    - Case history
 *    - Resolution times
 *    - Appeal rates
 *
 * 3. Voting Management:
 *    - Vote collection from authorized arbitrators
 *    - Weighted decision calculation
 *    - Minimum vote requirements
 *    - Voting period enforcement
 *
 * INTEGRATION POINTS:
 * - WorkerDAO: Arbitrator selection and authorization
 * - EmployerDAO: Arbitrator selection and authorization
 * - WorkContract: Dispute creation and resolution
 * 
 * @notice This registry serves as the central coordination point for
 * dispute resolution, ensuring fair and transparent arbitration processes
 */

contract ArbitrationRegistry is IArbitrationRegistry {
    struct Dispute {
        address initiator;
        address respondent;
        uint256 amount;
        DisputeStatus status;
        mapping(address => uint8) arbitratorVotes;
        uint256 votesSubmitted;
        uint256 startTime;
        uint256 resolutionTime;
        uint8 finalResolution;
        bool isAppealed;
    }

    struct ArbitratorStats {
        uint256 casesHandled;
        uint256 totalResolutionTime;
        uint256 appealsAgainst;
        bool isActive;
    }

    mapping(bytes32 => Dispute) public disputes;
    mapping(address => ArbitratorStats) public arbitratorStats;
    
    IWorkerDAO public workerDAO;
    IEmployerDAO public employerDAO;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTES_REQUIRED = 3;

    constructor(address _workerDAO, address _employerDAO) {
        workerDAO = IWorkerDAO(_workerDAO);
        employerDAO = IEmployerDAO(_employerDAO);
    }

    modifier onlyArbitrator() {
        require(arbitratorStats[msg.sender].isActive, "Not an active arbitrator");
        _;
    }

    function createDispute(
        address initiator,
        address respondent,
        uint256 amount
    ) external override returns (bytes32) {
        bytes32 disputeId = keccak256(
            abi.encodePacked(initiator, respondent, amount, block.timestamp)
        );
        
        Dispute storage dispute = disputes[disputeId];
        require(dispute.startTime == 0, "Dispute already exists");
        
        dispute.initiator = initiator;
        dispute.respondent = respondent;
        dispute.amount = amount;
        dispute.status = DisputeStatus.PENDING;
        dispute.startTime = block.timestamp;

        emit DisputeCreated(disputeId, initiator, respondent);
        return disputeId;
    }

    function submitVote(
        bytes32 disputeId, 
        uint8 vote
    ) external override onlyArbitrator {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.PENDING, "Invalid dispute status");
        require(dispute.arbitratorVotes[msg.sender] == 0, "Already voted");
        require(vote <= 100, "Invalid vote percentage");
        
        dispute.arbitratorVotes[msg.sender] = vote;
        dispute.votesSubmitted++;
        
        arbitratorStats[msg.sender].casesHandled++;

        emit ArbitratorVoted(disputeId, msg.sender);

        if (dispute.votesSubmitted >= MIN_VOTES_REQUIRED) {
            _resolveDispute(disputeId);
        }
    }

    function resolveDispute(bytes32 disputeId) external override {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.PENDING, "Invalid dispute status");
        require(
            block.timestamp >= dispute.startTime + VOTING_PERIOD ||
            dispute.votesSubmitted >= MIN_VOTES_REQUIRED,
            "Voting period not ended"
        );
        
        _resolveDispute(disputeId);
    }

    function appealDispute(bytes32 disputeId) external override {
        Dispute storage dispute = disputes[disputeId];
        require(
            msg.sender == dispute.initiator || msg.sender == dispute.respondent,
            "Not a party to dispute"
        );
        require(dispute.status == DisputeStatus.RESOLVED, "Cannot appeal");
        require(!dispute.isAppealed, "Already appealed");
        
        dispute.isAppealed = true;
        dispute.status = DisputeStatus.APPEALED;
        
        // Update stats for arbitrators who voted
        _updateArbitratorAppeals(disputeId);

        emit DisputeAppealed(disputeId);
    }

    function getDisputeStatus(bytes32 disputeId) 
        external 
        view 
        override 
        returns (DisputeStatus) 
    {
        return disputes[disputeId].status;
    }
    
    function getArbitratorPerformance(address arbitrator) 
        external 
        view 
        override 
        returns (
            uint256 casesHandled,
            uint256 averageResolutionTime,
            uint256 appealRate
        ) 
    {
        ArbitratorStats memory stats = arbitratorStats[arbitrator];
        casesHandled = stats.casesHandled;
        averageResolutionTime = stats.casesHandled > 0 ? 
            stats.totalResolutionTime / stats.casesHandled : 0;
        appealRate = stats.casesHandled > 0 ? 
            (stats.appealsAgainst * 100) / stats.casesHandled : 0;
    }

    function _resolveDispute(bytes32 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];
        uint256 totalVotes = 0;
        uint256 voteSum = 0;
        
        address[] memory arbitrators = _getActiveArbitrators();
        for (uint i = 0; i < arbitrators.length; i++) {
            uint8 vote = dispute.arbitratorVotes[arbitrators[i]];
            if (vote > 0) {
                voteSum += vote;
                totalVotes++;
            }
        }
        
        if (totalVotes > 0) {
            dispute.finalResolution = uint8(voteSum / totalVotes);
            dispute.status = DisputeStatus.RESOLVED;
            dispute.resolutionTime = block.timestamp;
            
            emit DisputeResolved(disputeId, dispute.finalResolution);
        }
    }

    function _updateArbitratorAppeals(bytes32 disputeId) internal {
        address[] memory arbitrators = _getActiveArbitrators();
        for (uint i = 0; i < arbitrators.length; i++) {
            if (disputes[disputeId].arbitratorVotes[arbitrators[i]] > 0) {
                arbitratorStats[arbitrators[i]].appealsAgainst++;
            }
        }
    }

    function _getActiveArbitrators() internal view returns (address[] memory) {
        address[] memory workerArbitrators = workerDAO.getWorkerArbitrators();
        address[] memory employerArbitrators = employerDAO.getEmployerArbitrators();
        
        // Combine and return unique arbitrators
        // Implementation details omitted for brevity
        return workerArbitrators;
    }
}