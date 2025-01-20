// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title WorkAgreementFactory
 * @dev Factory contract for creating and managing work agreements between workers and employers.
 * 
 * FUNCTIONALITY:
 * 1. Template Management
 *    - Create and manage contract templates
 *    - Configure payment structures
 *    - Set compliance requirements
 *    - Manage dispute settings
 *
 * 2. Contract Creation
 *    - Deploy new work contracts
 *    - Validate stakeholder requirements
 *    - Handle initial deposits
 *    - Setup associated components
 *
 * 3. Compliance Management
 *    - Verify worker compliance
 *    - Check insurance requirements
 *    - Validate certifications
 *    - Monitor working conditions
 *
 * 4. Reputation Integration
 *    - Check minimum scores
 *    - Validate stakeholder reputation
 *    - Track contract history
 *
 * STATE TRANSITIONS:
 * 1. Template Creation → Template Active
 * 2. Template Active → Contract Creation
 * 3. Template Active → Template Deactivated
 * 
 * SECURITY CONSIDERATIONS:
 * - Only owner can manage templates
 * - Compliance checks before contract creation
 * - Reputation requirements enforced
 * - Proper fund management
 */

import "./WorkContract.sol";
import "./interfaces/IPaymentStructure.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IGrievanceRegistry.sol";
import "./payment/PieceRatePayment.sol";
import "./payment/TimeBasedPayment.sol";
import "./payment/MilestonePayment.sol";
import "./payment/CustomPayment.sol";
import "./surveys/WorkerSurvey.sol";
import "./survey/SurveyRegistry.sol";
import "./interfaces/IWorkerDAO.sol";
import "./interfaces/IArbitration.sol";
import "./interfaces/IReputation.sol";
import "./interfaces/ICompliance.sol";
import "./interfaces/IGrievance.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WorkAgreementFactory is Ownable {
    // Organize template-related structures
    struct ContractTemplate {
        IPaymentStructure.PaymentType paymentType;
        IPaymentStructure.OracleType oracleType;
        address paymentImplementation;
        address oracleAddress;
        SurveyRegistry.Industry industry;
        string description;
        uint256 baseRate;
        uint256 minimumPayment;
        uint256 maximumPayment;
        bool active;
        DisputeSettings disputeSettings;
        ComplianceRequirements complianceRequirements;
    }

    struct DisputeSettings {
        uint256 votingPeriod;
        uint256 minVotesRequired;
        uint256 appealDeposit;
    }

    struct ComplianceRequirements {
        uint256 maxWeeklyHours;      // matches WORKING_HOURS
        uint256 minWageOverride;     // matches MINIMUM_WAGE
        uint256 minRestPeriod;       // matches REST_PERIODS
        bool requiresAgeVerification; // matches AGE_VERIFICATION
        bool requiresInsurance;       // matches INSURANCE
        bool requiresSafetyCert;      // matches SAFETY_CERT
    }

    // State variables
    mapping(uint256 => ContractTemplate) public templates;
    mapping(address => address[]) public employerContracts;
    mapping(address => address[]) public workerContracts;
    uint256 public templateCount;

    // External contracts
    WorkerSurvey public surveyContract;
    IGrievanceRegistry public grievanceRegistry;
    IArbitration public arbitrationSystem;
    IReputation public reputationSystem;
    ICompliance public complianceSystem;
    IGrievance public grievanceSystem;

    // Configuration
    uint256 public constant SURVEY_DEPOSIT_PERCENTAGE = 5;
    uint256 public minWorkerScore = 60;
    uint256 public minEmployerScore = 70;

    // New structs for job posting lifecycle
    struct JobPosting {
        uint256 templateId;
        address employer;
        address employerDAO;
        address governmentArbitrator;
        address laborNGO;
        address internationalBuyer;
        uint256 deposit;
        bool isActive;
        address[] applicants;
        address selectedWorker;
        bool workerAccepted;
        bool employerConfirmed;
        uint256 deadline;
    }

    // Mapping to track job postings
    mapping(uint256 => JobPosting) public jobPostings;
    uint256 public jobPostingCount;

    // Events
    event TemplateCreated(uint256 indexed templateId, string description);
    event ContractCreated(
        address indexed contractAddress,
        uint256 indexed templateId,
        address indexed worker,
        address employer
    );
    event TemplateDeactivated(uint256 indexed templateId);
    event ComplianceRequirementsUpdated(uint256 indexed templateId);
    event MinimumScoresUpdated(uint256 workerScore, uint256 employerScore);
    event TemplateConfigured(
        uint256 indexed templateId,
        address paymentImpl,
        address oracle
    );
    
    event ComplianceVerified(
        address indexed worker,
        uint256 indexed templateId,
        bool success
    );
    
    event ReputationChecked(
        address indexed entity,
        uint256 score,
        uint256 required
    );

    // Events for the UI to track
    event JobPosted(
        uint256 indexed jobId,
        uint256 indexed templateId,
        address indexed employer
    );
    event WorkerApplied(uint256 indexed jobId, address indexed worker);
    event WorkerSelected(uint256 indexed jobId, address indexed worker);
    event WorkerAccepted(uint256 indexed jobId, address indexed worker);
    event JobConfirmed(uint256 indexed jobId, address indexed worker, address indexed employer);
    event JobCancelled(uint256 indexed jobId);

    // Custom errors
    error InvalidTemplate(uint256 templateId);
    error InsufficientReputation(address entity, uint256 score, uint256 required);
    error ComplianceCheckFailed(string requirement);
    error InvalidScoreRange();

    constructor(
        address _grievanceRegistry,
        address _arbitrationSystem,
        address _reputationSystem,
        address _complianceSystem,
        address _grievanceSystem
    ) {
        grievanceRegistry = IGrievanceRegistry(_grievanceRegistry);
        arbitrationSystem = IArbitration(_arbitrationSystem);
        reputationSystem = IReputation(_reputationSystem);
        complianceSystem = ICompliance(_complianceSystem);
        grievanceSystem = IGrievance(_grievanceSystem);
        surveyContract = new WorkerSurvey();
    }

    function createTemplate(
        IPaymentStructure.PaymentType _paymentType,
        IPaymentStructure.OracleType _oracleType,
        address _paymentImplementation,
        address _oracleAddress,
        SurveyRegistry.Industry _industry,
        string memory _description,
        uint256 _baseRate,
        uint256 _minimumPayment,
        uint256 _maximumPayment
    ) external onlyOwner returns (uint256) {
        require(
            _oracleType == IPaymentStructure.OracleType.GPS ||
            _oracleType == IPaymentStructure.OracleType.IMAGE ||
            _oracleType == IPaymentStructure.OracleType.WEIGHT ||
            _oracleType == IPaymentStructure.OracleType.TIME_CLOCK,
            "Invalid oracle type"
        );

        templateCount++;
        templates[templateCount] = ContractTemplate({
            paymentType: _paymentType,
            oracleType: _oracleType,
            paymentImplementation: _paymentImplementation,
            oracleAddress: _oracleAddress,
            industry: _industry,
            description: _description,
            baseRate: _baseRate,
            minimumPayment: _minimumPayment,
            maximumPayment: _maximumPayment,
            active: true,
            disputeSettings: DisputeSettings(0, 0, 0),
            complianceRequirements: ComplianceRequirements(0, 0, 0, false, false, false)
        });

        emit TemplateCreated(templateCount, _description);
        return templateCount;
    }

    function createWorkAgreement(
        uint256 templateId,
        address worker,
        address employer,
        address workerDAO,
        address employerDAO,
        address governmentArbitrator,
        address laborNGO,
        address internationalBuyer
    ) external payable returns (address) {
        ContractTemplate memory template = templates[templateId];
        if (!template.active) {
            revert InvalidTemplate(templateId);
        }
        if (msg.value < template.minimumPayment) {
            revert("Insufficient initial funding");
        }

        // Check reputation requirements
        uint256 workerScore = reputationSystem.getScore(worker, IReputation.ReputationType.WORKER);
        if (workerScore < minWorkerScore) {
            revert InsufficientReputation(worker, workerScore, minWorkerScore);
        }

        uint256 employerScore = reputationSystem.getScore(employer, IReputation.ReputationType.EMPLOYER);
        if (employerScore < minEmployerScore) {
            revert InsufficientReputation(employer, employerScore, minEmployerScore);
        }

        // Check compliance requirements
        _verifyCompliance(templateId, worker);

        // Create and setup the work contract
        address workContract = _createAndSetupContract(
            template,
            worker,
            employer,
            workerDAO,
            employerDAO,
            governmentArbitrator,
            laborNGO,
            internationalBuyer,
            msg.value
        );

        // Track the contract
        employerContracts[employer].push(workContract);
        workerContracts[worker].push(workContract);
        
        emit ContractCreated(workContract, templateId, worker, employer);
        return workContract;
    }

    function _verifyCompliance(uint256 templateId, address worker) internal view {
        ComplianceRequirements memory requirements = templates[templateId].complianceRequirements;
        
        if (requirements.requiresInsurance && !complianceSystem.isInsuranceValid(worker)) {
            revert ComplianceCheckFailed("Insurance required");
        }

        if (requirements.requiresSafetyCert) {
            (,, bool isCompliant) = complianceSystem.getComplianceStatus(
                worker,
                ICompliance.ComplianceType.SAFETY_CERT
            );
            if (!isCompliant) {
                revert ComplianceCheckFailed("Safety certification required");
            }
        }
    }

    function _createAndSetupContract(
        ContractTemplate memory template,
        address worker,
        address employer,
        address workerDAO,
        address employerDAO,
        address governmentArbitrator,
        address laborNGO,
        address internationalBuyer,
        uint256 value
    ) internal returns (address) {
        // Calculate survey deposit
        uint256 surveyDeposit = (value * SURVEY_DEPOSIT_PERCENTAGE) / 100;
        uint256 contractValue = value - surveyDeposit;

        // Create work contract
        WorkContract agreement = new WorkContract{value: contractValue}(
            worker,
            employer,
            workerDAO,
            employerDAO,
            address(arbitrationSystem),
            laborNGO,
            internationalBuyer,
            template.paymentImplementation,
            address(surveyContract),
            template.industry,
            address(grievanceRegistry),
            address(reputationSystem),
            address(complianceSystem)
        );

        // Setup additional components
        grievanceRegistry.authorizeContract(address(agreement));
        payable(address(surveyContract)).transfer(surveyDeposit);
        surveyContract.addEmployerDeposit{value: surveyDeposit}();

        return address(agreement);
    }

    // Admin functions
    function setTemplateDisputeSettings(
        uint256 templateId,
        uint256 votingPeriod,
        uint256 minVotesRequired,
        uint256 appealDeposit
    ) external onlyOwner {
        if (!templates[templateId].active) {
            revert InvalidTemplate(templateId);
        }
        
        templates[templateId].disputeSettings = DisputeSettings({
            votingPeriod: votingPeriod,
            minVotesRequired: minVotesRequired,
            appealDeposit: appealDeposit
        });
    }

    function setMinimumScores(
        uint256 _minWorkerScore,
        uint256 _minEmployerScore
    ) external onlyOwner {
        if (_minWorkerScore > 100 || _minEmployerScore > 100) {
            revert InvalidScoreRange();
        }
        minWorkerScore = _minWorkerScore;
        minEmployerScore = _minEmployerScore;
        emit MinimumScoresUpdated(_minWorkerScore, _minEmployerScore);
    }

    function setTemplateCompliance(
        uint256 templateId,
        uint256 maxWeeklyHours,
        uint256 minWageOverride,
        uint256 minRestPeriod,
        bool requiresAgeVerification,
        bool requiresInsurance,
        bool requiresSafetyCert
    ) external onlyOwner {
        if (!templates[templateId].active) {
            revert InvalidTemplate(templateId);
        }

        templates[templateId].complianceRequirements = ComplianceRequirements({
            maxWeeklyHours: maxWeeklyHours,
            minWageOverride: minWageOverride,
            minRestPeriod: minRestPeriod,
            requiresAgeVerification: requiresAgeVerification,
            requiresInsurance: requiresInsurance,
            requiresSafetyCert: requiresSafetyCert
        });

        emit ComplianceRequirementsUpdated(templateId);
    }

    function deactivateTemplate(uint256 templateId) external onlyOwner {
        if (!templates[templateId].active) {
            revert InvalidTemplate(templateId);
        }
        templates[templateId].active = false;
        emit TemplateDeactivated(templateId);
    }

    // View functions
    function getEmployerContracts(address employer) external view returns (address[] memory) {
        return employerContracts[employer];
    }

    function getWorkerContracts(address worker) external view returns (address[] memory) {
        return workerContracts[worker];
    }

    // Testing helper functions
    /**
     * @dev Get complete template information
     * @param templateId The ID of the template to query
     * @return Complete template struct with all settings
     */
    function getTemplateDetails(uint256 templateId)
        external
        view
        returns (
            ContractTemplate memory template,
            bool exists
        )
    {
        template = templates[templateId];
        exists = template.active || template.paymentImplementation != address(0);
    }

    /**
     * @dev Get all active templates
     * @return templateIds Array of active template IDs
     */
    function getActiveTemplates() 
        external 
        view 
        returns (uint256[] memory templateIds) 
    {
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= templateCount; i++) {
            if (templates[i].active) {
                activeCount++;
            }
        }
        
        templateIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= templateCount; i++) {
            if (templates[i].active) {
                templateIds[index] = i;
                index++;
            }
        }
    }

    /**
     * @dev Get contracts created from a specific template
     * @param templateId The template ID to query
     * @return contracts Array of contract addresses
     */
    function getContractsByTemplate(uint256 templateId)
        external
        view
        returns (address[] memory contracts)
    {
        // Implementation would require additional mapping
        // Added here as interface example
    }

    /**
     * @dev Verify if an address can create a contract
     * @param worker Worker address to check
     * @param employer Employer address to check
     * @param templateId Template ID to use
     * @return canCreate Whether contract can be created
     * @return reason Reason if cannot create
     */
    function canCreateContract(
        address worker,
        address employer,
        uint256 templateId
    )
        external
        view
        returns (
            bool canCreate,
            string memory reason
        )
    {
        try this.checkRequirements(worker, employer, templateId) {
            return (true, "");
        } catch Error(string memory _reason) {
            return (false, _reason);
        }
    }

    /**
     * @dev Internal function to check all requirements
     * @param worker Worker address
     * @param employer Employer address
     * @param templateId Template ID
     */
    function checkRequirements(
        address worker,
        address employer,
        uint256 templateId
    ) external view {
        // Check template
        ContractTemplate memory template = templates[templateId];
        if (!template.active) {
            revert InvalidTemplate(templateId);
        }

        // Check reputation
        uint256 workerScore = reputationSystem.getScore(
            worker,
            IReputation.ReputationType.WORKER
        );
        if (workerScore < minWorkerScore) {
            revert InsufficientReputation(
                worker,
                workerScore,
                minWorkerScore
            );
        }

        uint256 employerScore = reputationSystem.getScore(
            employer,
            IReputation.ReputationType.EMPLOYER
        );
        if (employerScore < minEmployerScore) {
            revert InsufficientReputation(
                employer,
                employerScore,
                minEmployerScore
            );
        }

        // Check compliance
        _verifyCompliance(templateId, worker);
    }

    /**
     * @dev Get statistics about created contracts
     * @return totalContracts Total number of contracts created
     * @return activeContracts Number of active contracts
     * @return totalTemplates Number of templates created
     * @return activeTemplates Number of active templates
     */
    function getFactoryStatistics()
        external
        view
        returns (
            uint256 totalContracts,
            uint256 activeContracts,
            uint256 totalTemplates,
            uint256 activeTemplates
        )
    {
        totalTemplates = templateCount;
        
        for (uint256 i = 1; i <= templateCount; i++) {
            if (templates[i].active) {
                activeTemplates++;
            }
        }
        
        // Note: Would need additional tracking for contract statistics
    }

    // Post a new job
    function postJob(
        uint256 templateId,
        address employerDAO,
        address governmentArbitrator,
        address laborNGO,
        address internationalBuyer,
        uint256 deadline
    ) external payable returns (uint256) {
        ContractTemplate memory template = templates[templateId];
        require(template.active, "Invalid template");
        require(msg.value >= template.minimumPayment, "Insufficient deposit");
        
        jobPostingCount++;
        JobPosting storage job = jobPostings[jobPostingCount];
        
        job.templateId = templateId;
        job.employer = msg.sender;
        job.employerDAO = employerDAO;
        job.governmentArbitrator = governmentArbitrator;
        job.laborNGO = laborNGO;
        job.internationalBuyer = internationalBuyer;
        job.deposit = msg.value;
        job.isActive = true;
        job.deadline = deadline;
        
        emit JobPosted(jobPostingCount, templateId, msg.sender);
        return jobPostingCount;
    }

    // Worker applies for job
    function applyForJob(uint256 jobId) external {
        JobPosting storage job = jobPostings[jobId];
        require(job.isActive, "Job not active");
        require(block.timestamp < job.deadline, "Application deadline passed");
        
        // Check worker reputation
        uint256 workerScore = reputationSystem.getScore(msg.sender, IReputation.ReputationType.WORKER);
        require(workerScore >= minWorkerScore, "Insufficient reputation score");
        
        job.applicants.push(msg.sender);
        emit WorkerApplied(jobId, msg.sender);
    }

    // Employer selects a worker
    function selectWorker(uint256 jobId, address worker) external {
        JobPosting storage job = jobPostings[jobId];
        require(msg.sender == job.employer, "Not the employer");
        require(job.isActive, "Job not active");
        
        bool isApplicant = false;
        for (uint i = 0; i < job.applicants.length; i++) {
            if (job.applicants[i] == worker) {
                isApplicant = true;
                break;
            }
        }
        require(isApplicant, "Worker did not apply");
        
        job.selectedWorker = worker;
        emit WorkerSelected(jobId, worker);
    }

    // Worker accepts the job
    function acceptJob(uint256 jobId) external {
        JobPosting storage job = jobPostings[jobId];
        require(msg.sender == job.selectedWorker, "Not selected worker");
        require(job.isActive, "Job not active");
        
        job.workerAccepted = true;
        emit WorkerAccepted(jobId, msg.sender);
    }

    // Employer confirms and creates the final contract
    function confirmAndCreateContract(uint256 jobId) external {
        JobPosting storage job = jobPostings[jobId];
        require(msg.sender == job.employer, "Not the employer");
        require(job.workerAccepted, "Worker hasn't accepted");
        require(job.isActive, "Job not active");
        
        // Create the actual work contract
        address workContract = _createAndSetupContract(
            templates[job.templateId],
            job.selectedWorker,
            job.employer,
            job.selectedWorker, // workerDAO - could be passed in separately
            job.employerDAO,
            job.governmentArbitrator,
            job.laborNGO,
            job.internationalBuyer,
            job.deposit
        );
        
        job.isActive = false;
        job.employerConfirmed = true;
        
        emit JobConfirmed(jobId, job.selectedWorker, job.employer);
        emit ContractCreated(workContract, job.templateId, job.selectedWorker, job.employer);
    }
}