// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IReputation.sol";
import "../interfaces/IArbitration.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ReputationRegistry
 * @dev Manages reputation scores for workers and employers
 * 
 * FUNCTIONALITY:
 * 1. Score Management:
 *    - Weighted scoring system
 *    - Historical tracking
 *    - Dispute impact handling
 *    - Stake-based reputation
 *
 * 2. Security Features:
 *    - Role-based access
 *    - Score validation
 *    - Stake requirements
 *    - Proof verification
 *
 * 3. Recovery Systems:
 *    - Score appeals
 *    - Stake recovery
 *    - Reputation rehabilitation
 */

contract ReputationRegistry is IReputation, Pausable, AccessControl {
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct DetailedScore {
        uint256 overallScore;
        uint256 completionScore;
        uint256 timelinessScore;
        uint256 communicationScore;
        uint256 qualityScore;
        uint256 paymentScore;
        uint256 fairnessScore;
        uint256 totalContracts;
        uint256 disputeCount;
        uint256 stakedAmount;
        uint256 lastUpdateBlock;
    }

    // Entity => Type => DetailedScore
    mapping(address => mapping(ReputationType => DetailedScore)) private scores;
    
    // Minimum stake requirements
    mapping(ReputationType => uint256) public minimumStake;
    
    // Score weights for different factors
    mapping(ScoreFactors => uint256) public factorWeights;
    
    uint256 public constant MAX_SCORE = 100;
    uint256 public constant SCORE_DECIMALS = 2;
    uint256 public constant DECAY_PERIOD = 90 days;
    uint256 public constant DECAY_RATE = 5; // 5% decay per period

    IArbitration public arbitrationSystem;

    // Add new state variables
    uint256 public constant RECOVERY_PERIOD = 180 days;
    uint256 public constant RECOVERY_THRESHOLD = 50;
    uint256 public constant PRIVACY_THRESHOLD = 5; // Minimum contracts for public score
    
    // Privacy settings
    struct PrivacySettings {
        bool detailedScorePrivate;
        bool disputeHistoryPrivate;
        mapping(address) allowed viewers;
    }
    
    // Recovery tracking
    struct RecoveryProgress {
        uint256 startTime;
        uint256 successfulContracts;
        bool inProgress;
    }

    mapping(address => PrivacySettings) private privacySettings;
    mapping(address => RecoveryProgress) private recoveryProgress;
    mapping(address => mapping(address => bool)) private viewPermissions;

    // Add new events
    event PrivacyUpdated(address indexed entity, bool detailedScorePrivate);
    event ViewerAuthorized(address indexed entity, address indexed viewer);
    event RecoveryStarted(address indexed entity);
    event RecoveryCompleted(address indexed entity);

    constructor(address _arbitrationSystem) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        arbitrationSystem = IArbitration(_arbitrationSystem);
        
        // Initialize weights
        factorWeights[ScoreFactors.COMPLETION] = 25;
        factorWeights[ScoreFactors.TIMELINESS] = 15;
        factorWeights[ScoreFactors.COMMUNICATION] = 15;
        factorWeights[ScoreFactors.QUALITY] = 20;
        factorWeights[ScoreFactors.PAYMENT] = 15;
        factorWeights[ScoreFactors.FAIRNESS] = 10;

        // Initialize minimum stakes
        minimumStake[ReputationType.WORKER] = 0.1 ether;
        minimumStake[ReputationType.EMPLOYER] = 1 ether;
    }

    modifier onlyUpdater() {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        _;
    }

    modifier validEntity(address entity, ReputationType entityType) {
        require(entity != address(0), "Invalid entity address");
        require(
            scores[entity][entityType].stakedAmount >= minimumStake[entityType],
            "Insufficient stake"
        );
        _;
    }

    function updateScore(
        address entity,
        ReputationType entityType,
        ScoreFactors factor,
        uint256 score,
        bytes calldata proof
    ) 
        external 
        override 
        onlyUpdater 
        validEntity(entity, entityType)
        whenNotPaused 
    {
        require(score <= MAX_SCORE, "Score exceeds maximum");
        require(_verifyProof(proof), "Invalid proof");

        DetailedScore storage entityScore = scores[entity][entityType];
        
        // Apply decay if needed
        _applyScoreDecay(entity, entityType);

        // Update specific factor score
        _updateFactorScore(entityScore, factor, score);

        // Recalculate overall score
        entityScore.overallScore = _calculateOverallScore(entityScore);
        entityScore.lastUpdateBlock = block.number;
        entityScore.totalContracts++;

        emit ScoreUpdated(entity, entityType, entityScore.overallScore, factor);

        // Check for recovery progress
        RecoveryProgress storage recovery = recoveryProgress[entity];
        if (recovery.inProgress) {
            if (score >= 80) { // High performance during recovery
                recovery.successfulContracts++;
                
                // Check if recovery is complete
                if (recovery.successfulContracts >= 5 && 
                    block.timestamp <= recovery.startTime + RECOVERY_PERIOD) {
                    // Boost score for successful recovery
                    scores[entity][entityType].overallScore = 
                        Math.min(RECOVERY_THRESHOLD, scores[entity][entityType].overallScore + 10);
                    recovery.inProgress = false;
                    emit RecoveryCompleted(entity);
                }
            }
        }
    }

    function handleDisputeOutcome(
        address entity,
        ReputationType entityType,
        bool won
    ) 
        external 
        override 
        onlyUpdater 
        validEntity(entity, entityType) 
    {
        DetailedScore storage entityScore = scores[entity][entityType];
        entityScore.disputeCount++;

        int256 scoreChange = won ? int256(5) : int256(-10);
        
        // Apply score change with bounds checking
        if (scoreChange > 0) {
            entityScore.overallScore = Math.min(
                entityScore.overallScore + uint256(scoreChange),
                MAX_SCORE
            );
        } else {
            entityScore.overallScore = Math.max(
                entityScore.overallScore - uint256(-scoreChange),
                0
            );
        }

        emit DisputeImpact(entity, entityType, scoreChange);
    }

    function depositStake() 
        external 
        payable 
        override 
        whenNotPaused 
    {
        ReputationType entityType = msg.value >= minimumStake[ReputationType.EMPLOYER] 
            ? ReputationType.EMPLOYER 
            : ReputationType.WORKER;
            
        require(
            msg.value >= minimumStake[entityType],
            "Insufficient stake amount"
        );

        scores[msg.sender][entityType].stakedAmount += msg.value;
        
        emit StakeDeposited(msg.sender, entityType, msg.value);
    }

    function getScore(address entity, ReputationType entityType) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return scores[entity][entityType].overallScore;
    }

    function getDetailedScore(address entity, ReputationType entityType)
        external
        view
        override
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
        )
    {
        DetailedScore storage score = scores[entity][entityType];
        PrivacySettings storage privacy = privacySettings[entity];

        require(
            !privacy.detailedScorePrivate || 
            msg.sender == entity ||
            privacy.allowedViewers[msg.sender] ||
            hasRole(ADMIN_ROLE, msg.sender),
            "Detailed score is private"
        );

        // Only show dispute count if allowed
        uint256 displayedDisputes = privacy.disputeHistoryPrivate ? 
            0 : score.disputeCount;

        // Only show detailed scores if enough contracts
        if (score.totalContracts < PRIVACY_THRESHOLD) {
            return (
                score.overallScore,
                0, 0, 0, 0, 0, 0,
                score.totalContracts,
                0
            );
        }

        return (
            score.overallScore,
            score.completionScore,
            score.timelinessScore,
            score.communicationScore,
            score.qualityScore,
            score.paymentScore,
            score.fairnessScore,
            score.totalContracts,
            displayedDisputes
        );
    }

    // Internal functions
    function _updateFactorScore(
        DetailedScore storage score,
        ScoreFactors factor,
        uint256 newScore
    ) internal {
        if (factor == ScoreFactors.COMPLETION) score.completionScore = newScore;
        else if (factor == ScoreFactors.TIMELINESS) score.timelinessScore = newScore;
        else if (factor == ScoreFactors.COMMUNICATION) score.communicationScore = newScore;
        else if (factor == ScoreFactors.QUALITY) score.qualityScore = newScore;
        else if (factor == ScoreFactors.PAYMENT) score.paymentScore = newScore;
        else if (factor == ScoreFactors.FAIRNESS) score.fairnessScore = newScore;
    }

    function _calculateOverallScore(DetailedScore memory score) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 weightedSum = 
            score.completionScore * factorWeights[ScoreFactors.COMPLETION] +
            score.timelinessScore * factorWeights[ScoreFactors.TIMELINESS] +
            score.communicationScore * factorWeights[ScoreFactors.COMMUNICATION] +
            score.qualityScore * factorWeights[ScoreFactors.QUALITY] +
            score.paymentScore * factorWeights[ScoreFactors.PAYMENT] +
            score.fairnessScore * factorWeights[ScoreFactors.FAIRNESS];

        return weightedSum / 100; // Weights sum to 100
    }

    function _applyScoreDecay(address entity, ReputationType entityType) 
        internal 
    {
        DetailedScore storage score = scores[entity][entityType];
        uint256 timeSinceUpdate = block.timestamp - score.lastUpdateBlock;
        
        if (timeSinceUpdate >= DECAY_PERIOD) {
            uint256 decayPeriods = timeSinceUpdate / DECAY_PERIOD;
            uint256 decayFactor = DECAY_RATE * decayPeriods;
            
            if (decayFactor > 0) {
                score.overallScore = score.overallScore * 
                    (100 - decayFactor) / 100;
            }
        }
    }

    function _verifyProof(bytes calldata proof) 
        internal 
        pure 
        returns (bool) 
    {
        // Implement proof verification logic
        return true;
    }

    // Admin functions
    function setMinimumStake(
        ReputationType entityType,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        minimumStake[entityType] = amount;
    }

    function setFactorWeight(
        ScoreFactors factor,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) {
        require(weight <= 100, "Weight too high");
        factorWeights[factor] = weight;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Add privacy management
    function updatePrivacySettings(
        bool _detailedScorePrivate,
        bool _disputeHistoryPrivate
    ) external {
        PrivacySettings storage settings = privacySettings[msg.sender];
        settings.detailedScorePrivate = _detailedScorePrivate;
        settings.disputeHistoryPrivate = _disputeHistoryPrivate;
        emit PrivacyUpdated(msg.sender, _detailedScorePrivate);
    }

    function authorizeViewer(address viewer) external {
        privacySettings[msg.sender].allowedViewers[viewer] = true;
        emit ViewerAuthorized(msg.sender, viewer);
    }

    // Add recovery mechanisms
    function startRecovery() external {
        require(
            scores[msg.sender][ReputationType.WORKER].overallScore < RECOVERY_THRESHOLD,
            "Score too high for recovery"
        );
        
        RecoveryProgress storage recovery = recoveryProgress[msg.sender];
        require(!recovery.inProgress, "Recovery already in progress");
        
        recovery.startTime = block.timestamp;
        recovery.successfulContracts = 0;
        recovery.inProgress = true;
        
        emit RecoveryStarted(msg.sender);
    }

    // Add fairness mechanisms
    function appealScore(
        ScoreFactors factor,
        bytes calldata evidence
    ) external {
        require(
            scores[msg.sender][ReputationType.WORKER].totalContracts >= PRIVACY_THRESHOLD,
            "Not enough contract history"
        );
        
        // Create appeal case in arbitration system
        bytes32 appealId = arbitrationSystem.createDispute(
            msg.sender,
            address(this),
            0
        );
        
        // Logic to handle score appeal
        // Could involve DAO voting or arbitrator review
    }
}