// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IOracle.sol";
import "./interfaces/IEmployerDAO.sol";
import "./interfaces/IWorkerDAO.sol";
import "./interfaces/IPaymentStructure.sol";
import "./interfaces/IGrievance.sol";
import "./surveys/WorkerSurvey.sol";
import "./survey/SurveyRegistry.sol";
import "./interfaces/IArbitration.sol";
import "./interfaces/IEscrow.sol";
import "./interfaces/IReputation.sol";
import "./interfaces/ICompliance.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title WorkContract
 * @dev Core contract managing the relationship between workers and employers
 * 
 * STRUCTURE:
 * 1. Stakeholder Management:
 *    - Worker and employer relationship
 *    - DAO connections (WorkerDAO and EmployerDAO)
 *    - Arbitrators (worker, employer, and government)
 *    - External parties (NGOs, international buyers)
 *
 * 2. Payment Systems:
 *    - Multiple payment structures (time, piece-rate, milestone, custom)
 *    - Payment verification through oracles
 *    - Dispute resolution for payments
 *    - Minimum/maximum payment enforcement
 *
 * 3. Work Verification:
 *    - Oracle integration (GPS, image, weight)
 *    - Multi-oracle support
 *    - Work completion tracking
 *    - Quality assurance
 *
 * 4. Grievance Handling:
 *    - Anonymous reporting system
 *    - Status tracking
 *    - Resolution processes
 *    - Stakeholder mediation
 *
 * 5. Survey Integration:
 *    - Industry-specific questionnaires
 *    - Random question selection
 *    - Response tracking
 *    - Compliance monitoring
 *
 * FEATURES:
 * - Flexible payment structures
 * - Multi-stakeholder dispute resolution
 * - Worker protection mechanisms
 * - Transparent verification systems
 * - Grievance management
 * - Survey-based monitoring
 *
 * INTEGRATIONS:
 * - WorkerDAO and EmployerDAO
 * - Payment structure contracts
 * - Oracle contracts
 * - Survey system
 * - Grievance registry
 *
 * @notice This contract serves as the primary agreement between workers and employers
 * @dev Manages the agreement between worker and employer with integrated systems
 * for payments, compliance, reputation, grievances, and dispute resolution
 */
contract WorkContract is ReentrancyGuard {
    //------------------------------------------------------------------------------
    // Core Contract State
    //------------------------------------------------------------------------------
    struct ContractState {
        bool isActive;
        bool workCompleted;
        bool qualityVerified;
        uint256 startTime;
        uint256 completionTime;
        uint256 deadline;
        Job job;
    }

    struct DisputeState {
        bool isActive;
        bool appealActive;
        bytes32 activeDisputeId;
        uint256 disputeDeadline;
        mapping(address => bool) hasVotedOnDispute;
        uint8 votesForWorker;
        uint8 votesForEmployer;
        uint8 totalVotesCast;
    }

    struct StakeholderInfo {
        address worker;
        address employer;
        address workerDAO;
        address employerDAO;
        address governmentArbitrator;
        address workerArbitrator;
        address employerArbitrator;
        address laborNGO;        // Default for missing WorkerDAO
        address internationalBuyer; // Default for missing EmployerDAO
    }

    // Reputation tracking
    struct ReputationScore {
        uint256 totalScore;
        uint256 numRatings;
        uint256 disputesRaised;
        uint256 disputesWon;
        uint256 completedContracts;
        mapping(bytes32 => bool) ratedContracts;
    }

    // State variables organized
    ContractState public contractState;
    DisputeState public disputeState;
    StakeholderInfo public stakeholders;
    mapping(address => ReputationScore) private reputationScores;

    // Payment tracking
    struct PaymentInfo {
        uint256 currentPaymentNumber;
        uint256 totalPaymentAmount;
        mapping(uint256 => bytes32) paymentIds;
        mapping(uint256 => PaymentState) states;
        mapping(address => uint8) partialPaymentVotes;
    }

    PaymentInfo private paymentInfo;

    // Compliance tracking
    struct ComplianceInfo {
        bool verified;
        mapping(ICompliance.ComplianceType => bool) checks;
        uint256 lastVerificationTime;
    }

    ComplianceInfo public complianceInfo;

    IPaymentStructure public paymentStructure;

    IOracle public oracle;

    IArbitration public arbitrationSystem;

    IEscrow public escrow;

    IReputation public reputationSystem;

    ICompliance public complianceSystem;

    IGrievance public grievanceRegistry;

    uint256 public constant SURVEY_DEPOSIT_PERCENTAGE = 5; // 5% for surveys

    address public surveyContract;

    SurveyRegistry.Industry public industry;

    enum OracleType {
        GPS,
        IMAGE,
        WEIGHT,
        TIME_CLOCK
    }

    enum PaymentState {
        PENDING,
        COMPLIANCE_VERIFIED,
        CALCULATION_VERIFIED,
        ESCROW_CHECKED,
        COMPLETED
    }

    //------------------------------------------------------------------------------
    // Events
    //------------------------------------------------------------------------------
    // Payment & Escrow Events
    event PaymentDeposited(bytes32 paymentId, uint256 amount);
    event PaymentReleased(bytes32 paymentId, address recipient, uint256 amount);
    event PaymentDisputed(bytes32 paymentId, address disputeInitiator);
    
    // Compliance Events
    event ComplianceVerified(ICompliance.ComplianceType complianceType);
    event ComplianceWarning(string message);
    event ComplianceViolation(ICompliance.ComplianceType violationType);
    
    // Reputation Events
    event WorkCompleted(address worker, uint256 timestamp);
    event QualityVerified(address employer, uint256 qualityScore);
    
    // Grievance Events
    event GrievanceFiled(bytes32 grievanceId, address filer);
    event GrievanceResponded(bytes32 grievanceId, address responder);
    event GrievanceResolved(bytes32 grievanceId, string resolution);
    
    // Dispute Events
    event DisputeRaised(bytes32 disputeId, address initiator);
    event DisputeResolved(bytes32 disputeId, uint8 decision);
    
    // Lifecycle Events
    event ContractInitiated(address worker, address employer, uint256 templateId);
    event ContractTerminated(address terminator, uint256 timestamp);

    event JobCreated(bytes32 jobId, string description, address oracle, bytes criteria, bool useOracle);
    event JobVerified(bool success, bytes data);
    event DisputeRaised();
    event DisputeResolved(bool inFavorOfWorker);
    event VoteCast(address arbitrator, bool inFavorOfWorker);
    event WorkerRated(address worker, uint8 score);
    event EmployerRated(address employer, uint8 score);
    event AppealFiled();
    event AppealResolved(bool inFavorOfWorker);
    event ArbitratorsSelected(address workerArbitrator, address employerArbitrator);
    event WorkCompleted();
    event PaymentDeposited(bytes32 paymentId, uint256 amount);
    event ComplianceWarning(string message);
    event ComplianceViolation(ICompliance.ComplianceType violationType);

    // Additional events for testing and monitoring
    event StateTransition(string stateName, string fromState, string toState);
    event ComplianceCheck(ICompliance.ComplianceType complianceType, bool passed);
    event PaymentCalculation(uint256 amount, string calculationType);
    event StakeholderAction(address indexed stakeholder, string action);
    event ReputationUpdate(address indexed entity, uint256 oldScore, uint256 newScore);

    // Add custom errors at the contract level
    error Unauthorized(address caller, string action);
    error InvalidState(string message);
    error ComplianceError(ICompliance.ComplianceType complianceType, string message);
    error PaymentError(bytes32 paymentId, string message);
    error DisputeError(bytes32 disputeId, string message);
    error ValidationError(string message);

    constructor(
        address _worker,
        address _employer,
        address _workerDAO,
        address _employerDAO,
        address _governmentArbitrator,
        address _laborNGO,
        address _internationalBuyer,
        address _paymentStructure,
        address _surveyContract,
        SurveyRegistry.Industry _industry,
        address _grievanceRegistry,
        address _arbitrationSystem,
        address _escrow,
        address _reputationSystem,
        address _complianceSystem
    ) payable {
        require(msg.value > 0, "Employer must deposit payment upfront");
        
        stakeholders = StakeholderInfo({
            worker: _worker,
            employer: _employer,
            workerDAO: _workerDAO,
            employerDAO: _employerDAO,
            governmentArbitrator: _governmentArbitrator,
            workerArbitrator: address(0), // Set later
            employerArbitrator: address(0), // Set later
            laborNGO: _laborNGO,
            internationalBuyer: _internationalBuyer
        });
        
        contractState = ContractState({
            isActive: true,
            workCompleted: false,
            qualityVerified: false,
            startTime: block.timestamp,
            completionTime: 0,
            deadline: 0,
            job: Job({
                jobId: bytes32(0),
                description: "",
                verificationOracle: address(0),
                validationCriteria: new bytes(0),
                useOracle: false
            })
        });
        
        paymentStructure = IPaymentStructure(_paymentStructure);
        surveyContract = _surveyContract;
        paymentInfo.totalPaymentAmount = msg.value;
        industry = _industry;
        grievanceRegistry = IGrievance(_grievanceRegistry);
        arbitrationSystem = IArbitration(_arbitrationSystem);
        escrow = IEscrow(_escrow);
        reputationSystem = IReputation(_reputationSystem);
        complianceSystem = ICompliance(_complianceSystem);

        selectArbitrators();
    }

    function selectArbitrators() public {
        require(msg.sender == stakeholders.worker || msg.sender == stakeholders.employer, "Only contract participants can select arbitrators");

        // If WorkerDAO exists, pick an arbitrator from its pool
        if (stakeholders.workerDAO != address(0)) {
            stakeholders.workerArbitrator = selectFromDAO(IWorkerDAO(stakeholders.workerDAO).getWorkerArbitrators());
        } else {
            stakeholders.workerArbitrator = stakeholders.laborNGO;
        }

        // If EmployerDAO exists, pick an arbitrator from its pool
        if (stakeholders.employerDAO != address(0)) {
            stakeholders.employerArbitrator = selectFromDAO(IEmployerDAO(stakeholders.employerDAO).getEmployerArbitrators());
        } else {
            stakeholders.employerArbitrator = stakeholders.internationalBuyer;
        }

        emit ArbitratorsSelected(stakeholders.workerArbitrator, stakeholders.employerArbitrator);
    }

    function selectFromDAO(address[] memory arbitratorPool) internal view returns (address) {
        require(arbitratorPool.length > 0, "No arbitrators available in DAO");
        uint256 index = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % arbitratorPool.length;
        return arbitratorPool[index];
    }

    function createJob(
        bytes32 _jobId,
        string memory _description,
        address _verificationOracle,
        bytes memory _validationCriteria,
        bool _useOracle
    ) public {
        contractState.job = Job({
            jobId: _jobId,
            description: _description,
            verificationOracle: _verificationOracle,
            validationCriteria: _validationCriteria,
            useOracle: _useOracle
        });

        emit JobCreated(_jobId, _description, _verificationOracle, _validationCriteria, _useOracle);
    }

    function verifyJob() public {
        if (!contractState.job.useOracle) {
            revert ValidationError("Manual confirmation required");
        }

        try IOracle(contractState.job.verificationOracle).getVerificationData(contractState.job.jobId) returns (
            bool success,
            bytes memory data
        ) {
            if (success) {
                contractState.workCompleted = true;
                processPayment();
            } else {
                revert ValidationError("Oracle verification failed");
            }
            emit JobVerified(success, data);
        } catch Error(string memory reason) {
            revert ValidationError(string.concat("Oracle error: ", reason));
        } catch (bytes memory) {
            revert ValidationError("Oracle call failed");
        }
    }

    function confirmWorkManually() public {
        require(!contractState.job.useOracle, "Oracle required");
        contractState.workCompleted = true;
        releasePayment();
    }

    function raiseDispute(uint256 paymentNumber) external {
        if (msg.sender != stakeholders.worker && msg.sender != stakeholders.employer) {
            revert Unauthorized(msg.sender, "raise dispute");
        }
        if (disputeState.isActive) {
            revert DisputeError(disputeState.activeDisputeId, "Dispute already active");
        }
        
        bytes32 paymentId = paymentInfo.paymentIds[paymentNumber];
        if (paymentId == bytes32(0)) {
            revert PaymentError(paymentId, "Invalid payment number");
        }
        
        try escrow.disputePayment(paymentId) {
            try arbitrationSystem.createDispute(
                msg.sender,
                msg.sender == stakeholders.worker ? stakeholders.employer : stakeholders.worker,
                escrow.getBalance(paymentId)
            ) returns (bytes32 disputeId) {
                disputeState.activeDisputeId = disputeId;
                disputeState.isActive = true;
                emit DisputeRaised();
            } catch Error(string memory reason) {
                revert DisputeError(bytes32(0), string.concat("Arbitration creation failed: ", reason));
            }
        } catch Error(string memory reason) {
            revert PaymentError(paymentId, string.concat("Dispute payment failed: ", reason));
        }
    }

    function submitEvidence(
        bytes32 evidenceHash,
        string calldata evidenceType,
        string calldata metadataURI
    ) external {
        require(msg.sender == stakeholders.worker || msg.sender == stakeholders.employer, "Unauthorized");
        require(disputeState.isActive, "No active dispute");
        
        arbitrationSystem.submitEvidence(
            disputeState.activeDisputeId,
            evidenceHash,
            evidenceType,
            metadataURI
        );
    }

    function handleDisputeResolution() external {
        require(disputeState.isActive, "No active dispute");
        
        (uint8 decision, uint256 totalVotes, bool isComplete) = 
            arbitrationSystem.getVotingResult(disputeState.activeDisputeId);
            
        if (isComplete) {
            // Update reputation based on dispute outcome
            bool workerWon = decision >= 50;
            
            reputationSystem.handleDisputeOutcome(
                stakeholders.worker,
                IReputation.ReputationType.WORKER,
                workerWon
            );
            
            reputationSystem.handleDisputeOutcome(
                stakeholders.employer,
                IReputation.ReputationType.EMPLOYER,
                !workerWon
            );
            
            // Use emergency release in escrow with arbitration decision
            escrow.emergencyRelease(disputeState.activeDisputeId);
            
            disputeState.isActive = false;
            disputeState.activeDisputeId = bytes32(0);
            
            emit DisputeResolved(workerWon);
        }
    }

    function releasePayment() internal {
        payable(stakeholders.worker).transfer(paymentInfo.totalPaymentAmount);
        paymentInfo.totalPaymentAmount = 0;
        emit PaymentReleased(bytes32(0), stakeholders.worker, paymentInfo.totalPaymentAmount);
    }

    function fileAppeal() public {
        require(disputeState.isActive, "No active dispute");
        disputeState.appealActive = true;
        emit AppealFiled();
    }

    function resolveAppeal(bool inFavorOfWorker) public {
        require(disputeState.appealActive, "No active appeal");
        disputeState.appealActive = false;
        resolveDispute(inFavorOfWorker);
        emit AppealResolved(inFavorOfWorker);
    }

    function processPayment() internal nonReentrant {
        emit StateTransition(
            "Payment",
            "PENDING",
            "PROCESSING"
        );
        
        // 1. Check compliance first
        try complianceSystem.verifyCompliance(
            address(this),
            ICompliance.ComplianceType.WORKING_HOURS
        ) returns (bool compliant) {
            if (!compliant) {
                revert ComplianceError(
                    ICompliance.ComplianceType.WORKING_HOURS,
                    "Working hours non-compliant"
                );
            }
        } catch Error(string memory reason) {
            revert ComplianceError(
                ICompliance.ComplianceType.WORKING_HOURS,
                reason
            );
        }
        
        paymentInfo.states[paymentInfo.currentPaymentNumber] = PaymentState.COMPLIANCE_VERIFIED;

        // 2. Get and verify payment calculation
        try paymentStructure.calculatePaymentDue() returns (uint256 paymentDue) {
            if (paymentDue == 0) {
                revert PaymentError(bytes32(0), "No payment due");
            }
            
            bytes32 paymentId = paymentInfo.paymentIds[paymentInfo.currentPaymentNumber];
            if (paymentId == bytes32(0)) {
                revert PaymentError(paymentId, "Invalid payment ID");
            }
            
            paymentInfo.states[paymentInfo.currentPaymentNumber] = PaymentState.CALCULATION_VERIFIED;

            // 3. Check escrow status
            try escrow.getPaymentStatus(paymentId) returns (
                IEscrow.PaymentStatus status,
                uint256 amount,
                address depositor,
                uint256 depositTime
            ) {
                if (status != IEscrow.PaymentStatus.HELD) {
                    revert PaymentError(paymentId, "Payment not in escrow");
                }
                if (amount < paymentDue) {
                    revert PaymentError(paymentId, "Insufficient escrow balance");
                }
                
                paymentInfo.states[paymentInfo.currentPaymentNumber] = PaymentState.ESCROW_CHECKED;

                // 4. Process the payment
                try escrow.release(paymentId, stakeholders.worker, paymentDue) {
                    paymentInfo.states[paymentInfo.currentPaymentNumber] = PaymentState.COMPLETED;
                    paymentInfo.currentPaymentNumber++;
                    emit PaymentReleased(paymentId, stakeholders.worker, paymentDue);
                } catch Error(string memory reason) {
                    revert PaymentError(paymentId, string.concat("Release failed: ", reason));
                }
            } catch Error(string memory reason) {
                revert PaymentError(paymentId, string.concat("Escrow status check failed: ", reason));
            }
        } catch Error(string memory reason) {
            revert PaymentError(bytes32(0), string.concat("Payment calculation failed: ", reason));
        }
        
        emit StateTransition(
            "Payment",
            "PROCESSING",
            "COMPLETED"
        );
    }

    // Add helper function to check payment status
    function getPaymentStatus(uint256 paymentNumber) 
        external 
        view 
        returns (
            PaymentState state,
            bytes32 paymentId,
            uint256 amount
        ) 
    {
        paymentId = paymentInfo.paymentIds[paymentNumber];
        state = paymentInfo.states[paymentNumber];
        
        if (paymentId != bytes32(0)) {
            (, amount, ,) = escrow.getPaymentStatus(paymentId);
        }
    }

    function recordWork(uint256 amount, bytes memory proof) external {
        require(msg.sender == stakeholders.worker || msg.sender == stakeholders.employer, "Unauthorized");
        require(paymentStructure.recordWork(amount, proof), "Work recording failed");
        
        if (shouldProcessPayment()) {
            processPayment();
        }
    }

    function shouldProcessPayment() internal view returns (bool) {
        IPaymentStructure.PaymentConfig memory config = paymentStructure.getPaymentConfig();
        return block.timestamp >= config.nextPaymentDue;
    }

    function respondToSurvey(
        uint256 surveyId,
        uint256[] memory responses,
        bytes32 salt
    ) external {
        require(msg.sender == stakeholders.worker, "Only worker can respond");
        WorkerSurvey(surveyContract).submitResponse(surveyId, responses, salt);
    }

    function createIndustrySurvey(
        uint256[] memory _questionIds,
        uint256 _workerCount,
        uint256 _duration
    ) external returns (uint256) {
        require(msg.sender == stakeholders.employer, "Only employer can create surveys");
        return SurveyRegistry(surveyContract).createSurveyForIndustry(
            industry,
            _questionIds,
            _workerCount,
            _duration
        );
    }

    function fileGrievance(
        string calldata _category,
        string calldata _details,
        bytes32 _salt
    ) external returns (bytes32) {
        require(msg.sender == stakeholders.worker, "Only worker can file grievance");
        return grievanceRegistry.fileGrievance(
            stakeholders.worker,
            _category,
            _details,
            _salt
        );
    }

    function updateGrievanceStatus(
        bytes32 _grievanceId,
        IGrievance.GrievanceStatus _newStatus
    ) external {
        require(
            msg.sender == stakeholders.workerDAO || 
            msg.sender == stakeholders.employerDAO || 
            msg.sender == stakeholders.governmentArbitrator ||
            msg.sender == stakeholders.laborNGO,
            "Unauthorized to update grievance"
        );
        grievanceRegistry.updateGrievanceStatus(
            _grievanceId,
            _newStatus,
            msg.sender
        );
    }

    function getWorkerGrievances() external view returns (bytes32[] memory) {
        require(msg.sender == stakeholders.worker, "Only worker can view their grievances");
        return grievanceRegistry.getWorkerGrievances(stakeholders.worker);
    }

    function getGrievanceDetails(bytes32 _grievanceId) 
        external 
        view 
        returns (
            uint256 timestamp,
            string memory category,
            IGrievance.GrievanceStatus status,
            address workContract
        ) 
    {
        return grievanceRegistry.getGrievanceDetails(_grievanceId);
    }

    function completeWork() external onlyWorker onlyActiveContract {
        if (contractState.workCompleted) {
            revert InvalidState("Work already completed");
        }
        
        contractState.workCompleted = true;
        contractState.completionTime = block.timestamp;
        
        // Calculate timeliness score based on expected duration
        uint256 timelinessScore = _calculateTimelinessScore();
        
        // Update worker's completion and timeliness scores
        reputationSystem.updateScore(
            stakeholders.worker,
            IReputation.ReputationType.WORKER,
            IReputation.ScoreFactors.COMPLETION,
            100, // Full score for completion
            "" // Proof can be added if needed
        );
        
        reputationSystem.updateScore(
            stakeholders.worker,
            IReputation.ReputationType.WORKER,
            IReputation.ScoreFactors.TIMELINESS,
            timelinessScore,
            ""
        );
        
        // Update worker's DAO participation
        if (stakeholders.workerDAO != address(0)) {
            IWorkerDAO(stakeholders.workerDAO).recordActivity(stakeholders.worker, "CONTRACT_COMPLETION");
        }
        
        emit WorkCompleted();
    }

    function verifyQuality(uint256 qualityScore) 
        external 
        onlyEmployer 
        onlyActiveContract 
    {
        if (!contractState.workCompleted) {
            revert InvalidState("Work not completed");
        }
        if (contractState.qualityVerified) {
            revert InvalidState("Quality already verified");
        }
        if (qualityScore > 100) {
            revert ValidationError("Invalid score");
        }
        
        contractState.qualityVerified = true;
        
        // Update worker's quality score
        reputationSystem.updateScore(
            stakeholders.worker,
            IReputation.ReputationType.WORKER,
            IReputation.ScoreFactors.QUALITY,
            qualityScore,
            ""
        );
        
        // Update employer's fairness score
        reputationSystem.updateScore(
            stakeholders.employer,
            IReputation.ReputationType.EMPLOYER,
            IReputation.ScoreFactors.FAIRNESS,
            _calculateEmployerFairnessScore(),
            ""
        );
    }

    function setOracle(OracleType oracleType, address oracleAddress) external {
        require(msg.sender == stakeholders.employer, "Only employer can set oracle");
        if (oracleType == OracleType.TIME_CLOCK) {
            require(
                keccak256(bytes(IOracle(oracleAddress).getOracleType())) == 
                keccak256(bytes("TIME_CLOCK")),
                "Invalid oracle type"
            );
        }
        oracle = IOracle(oracleAddress);
    }

    function depositPayment() external payable {
        require(msg.sender == stakeholders.employer, "Only employer can deposit");
        require(msg.value > 0, "Amount must be positive");
        
        bytes32 paymentId = keccak256(
            abi.encodePacked(
                address(this),
                paymentInfo.currentPaymentNumber,
                block.timestamp
            )
        );
        
        escrow.deposit{value: msg.value}(paymentId);
        paymentInfo.paymentIds[paymentInfo.currentPaymentNumber] = paymentId;
        paymentInfo.currentPaymentNumber++;
        
        emit PaymentDeposited(paymentId, msg.value);
    }

    function releasePayment(uint256 paymentNumber) external {
        require(
            msg.sender == stakeholders.employer || msg.sender == address(this),
            "Unauthorized"
        );
        
        bytes32 paymentId = paymentInfo.paymentIds[paymentNumber];
        require(paymentId != bytes32(0), "Invalid payment number");
        
        (IEscrow.PaymentStatus status, uint256 amount, , ) = 
            escrow.getPaymentStatus(paymentId);
            
        require(status == IEscrow.PaymentStatus.HELD, "Invalid payment status");
        
        escrow.release(paymentId, stakeholders.worker, amount);
    }

    function _calculateTimelinessScore() internal view returns (uint256) {
        uint256 expectedDuration = 7 days; // Could be parameterized
        uint256 actualDuration = contractState.completionTime - contractState.startTime;
        
        if (actualDuration <= expectedDuration) {
            return 100;
        } else {
            uint256 delay = actualDuration - expectedDuration;
            uint256 penaltyPerDay = 5;
            uint256 penalty = (delay * penaltyPerDay) / 1 days;
            return penalty >= 100 ? 0 : 100 - penalty;
        }
    }

    function _calculateEmployerFairnessScore() internal view returns (uint256) {
        // Implementation based on payment timeliness, dispute history, etc.
        return 80; // Placeholder
    }

    function verifyCompliance() external {
        require(!complianceInfo.verified, "Compliance already verified");
        
        // Get template requirements
        ComplianceRequirements memory requirements = 
            factory.templateCompliance(templateId);
        
        // Check working hours
        require(
            complianceSystem.verifyCompliance(
                address(this),
                ICompliance.ComplianceType.WORKING_HOURS
            ),
            "Working hours non-compliant"
        );
        
        // Check minimum wage
        require(
            complianceSystem.verifyCompliance(
                address(this),
                ICompliance.ComplianceType.MINIMUM_WAGE
            ),
            "Wage non-compliant"
        );
        
        // Check rest periods
        require(
            complianceSystem.verifyCompliance(
                address(this),
                ICompliance.ComplianceType.REST_PERIODS
            ),
            "Rest periods non-compliant"
        );
        
        // Check age verification if required
        if (requirements.requiresAgeVerification) {
            require(
                complianceSystem.verifyCompliance(
                    address(this),
                    ICompliance.ComplianceType.AGE_VERIFICATION
                ),
                "Age verification required"
            );
        }
        
        // Check insurance if required
        if (requirements.requiresInsurance) {
            require(
                complianceSystem.verifyCompliance(
                    address(this),
                    ICompliance.ComplianceType.INSURANCE
                ),
                "Insurance required"
            );
        }
        
        // Check safety certification if required
        if (requirements.requiresSafetyCert) {
            require(
                complianceSystem.verifyCompliance(
                    address(this),
                    ICompliance.ComplianceType.SAFETY_CERT
                ),
                "Safety certification required"
            );
        }

        complianceInfo.verified = true;
    }

    function updateWorkingHours(uint256 hours) external {
        require(msg.sender == stakeholders.worker || msg.sender == stakeholders.employer, "Unauthorized");
        
        // Check if hours would exceed limits
        (uint256 currentRegular, uint256 currentOvertime) = 
            complianceSystem.checkWorkingHours(stakeholders.worker, weekStartTime);
            
        if (currentRegular + hours > 40) {
            emit ComplianceWarning("Weekly hours limit approaching");
        }
    }

    // Helper functions for state management
    function updateReputationScore(
        address entity,
        uint256 score,
        bytes32 contractId
    ) internal {
        ReputationScore storage reputation = reputationScores[entity];
        require(!reputation.ratedContracts[contractId], "Already rated");
        
        reputation.totalScore += score;
        reputation.numRatings++;
        reputation.ratedContracts[contractId] = true;
    }

    function getReputationScore(address entity) 
        external 
        view 
        returns (
            uint256 avgScore,
            uint256 totalRatings,
            uint256 disputeRatio
        ) 
    {
        ReputationScore storage reputation = reputationScores[entity];
        if (reputation.numRatings > 0) {
            avgScore = reputation.totalScore / reputation.numRatings;
        }
        totalRatings = reputation.numRatings;
        if (reputation.disputesRaised > 0) {
            disputeRatio = (reputation.disputesWon * 100) / reputation.disputesRaised;
        }
    }

    // Add role-based access control modifiers
    modifier onlyWorker() {
        if (msg.sender != stakeholders.worker) {
            revert Unauthorized(msg.sender, "worker only");
        }
        _;
    }

    modifier onlyEmployer() {
        if (msg.sender != stakeholders.employer) {
            revert Unauthorized(msg.sender, "employer only");
        }
        _;
    }

    modifier onlyArbitrator() {
        if (msg.sender != stakeholders.workerArbitrator && 
            msg.sender != stakeholders.employerArbitrator && 
            msg.sender != stakeholders.governmentArbitrator) {
            revert Unauthorized(msg.sender, "arbitrator only");
        }
        _;
    }

    modifier onlyDAO() {
        if (msg.sender != stakeholders.workerDAO && 
            msg.sender != stakeholders.employerDAO) {
            revert Unauthorized(msg.sender, "DAO only");
        }
        _;
    }

    modifier onlyActiveContract() {
        if (!contractState.isActive) {
            revert InvalidState("Contract not active");
        }
        _;
    }

    modifier notInDispute() {
        if (disputeState.isActive) {
            revert InvalidState("Contract in dispute");
        }
        _;
    }

    // Update functions with proper access control
    function resolveDispute(bool inFavorOfWorker) 
        external 
        onlyArbitrator 
        onlyActiveContract 
    {
        if (!disputeState.isActive) {
            revert InvalidState("No active dispute");
        }
        
        // Update reputation based on dispute outcome
        reputationSystem.handleDisputeOutcome(
            stakeholders.worker,
            IReputation.ReputationType.WORKER,
            inFavorOfWorker
        );
        
        reputationSystem.handleDisputeOutcome(
            stakeholders.employer,
            IReputation.ReputationType.EMPLOYER,
            !inFavorOfWorker
        );
        
        disputeState.isActive = false;
        emit DisputeResolved(inFavorOfWorker);
    }

    // View functions for testing
    /**
     * @dev Gets the current state of all contract components
     * @return A struct containing all major state variables
     */
    function getContractState() external view returns (
        bool isActive,
        bool workCompleted,
        bool qualityVerified,
        uint256 startTime,
        uint256 completionTime,
        bool inDispute,
        uint256 currentPayment
    ) {
        return (
            contractState.isActive,
            contractState.workCompleted,
            contractState.qualityVerified,
            contractState.startTime,
            contractState.completionTime,
            disputeState.isActive,
            paymentInfo.currentPaymentNumber
        );
    }

    /**
     * @dev Gets detailed payment information for testing
     * @param paymentNumber The payment number to query
     */
    function getDetailedPaymentInfo(uint256 paymentNumber) 
        external 
        view 
        returns (
            PaymentState state,
            bytes32 paymentId,
            uint256 amount,
            bool isDisputed
        ) 
    {
        paymentId = paymentInfo.paymentIds[paymentNumber];
        state = paymentInfo.states[paymentNumber];
        
        if (paymentId != bytes32(0)) {
            (IEscrow.PaymentStatus status, uint256 _amount, ,) = 
                escrow.getPaymentStatus(paymentId);
            amount = _amount;
            isDisputed = (status == IEscrow.PaymentStatus.DISPUTED);
        }
    }

    /**
     * @dev Gets compliance status for all types
     * @return types Array of compliance types checked
     * @return results Array of compliance check results
     */
    function getComplianceStatus() 
        external 
        view 
        returns (
            ICompliance.ComplianceType[] memory types,
            bool[] memory results
        ) 
    {
        types = new ICompliance.ComplianceType[](6);
        results = new bool[](6);
        
        for (uint i = 0; i < 6; i++) {
            types[i] = ICompliance.ComplianceType(i);
            results[i] = complianceInfo.checks[ICompliance.ComplianceType(i)];
        }
    }

    /**
     * @dev Helper function to validate state transitions
     * @param currentState Current state value
     * @param expectedState Expected state value
     * @param operation Name of the operation being performed
     */
    function _validateStateTransition(
        string memory currentState,
        string memory expectedState,
        string memory operation
    ) internal pure returns (bool) {
        if (keccak256(bytes(currentState)) != keccak256(bytes(expectedState))) {
            revert InvalidState(
                string.concat(
                    "Invalid state transition for ",
                    operation,
                    ": expected ",
                    expectedState,
                    " but got ",
                    currentState
                )
            );
        }
        return true;
    }
}
