// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ICompliance.sol";
import "../interfaces/ITimeClockOracle.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ComplianceRegistry
 * @dev Manages and enforces labor law compliance and working conditions
 * 
 * FEATURES:
 * 1. Working Hours Management
 * 2. Wage Compliance
 * 3. Certification Tracking
 * 4. Insurance Verification
 * 5. Safety Requirements
 */

contract ComplianceRegistry is ICompliance, AccessControl, Pausable {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct ComplianceRecord {
        VerificationStatus status;
        uint256 lastVerified;
        uint256 expiryDate;
        bool isCompliant;
        string details;
    }

    struct WorkingHoursRecord {
        uint256 weekStartTime;
        uint256 regularHours;
        uint256 overtimeHours;
        bool weekClosed;
    }

    struct Certification {
        bytes32 certificationId;
        uint256 issuanceDate;
        uint256 expiryDate;
        bool isValid;
    }

    // Contract => ComplianceType => ComplianceRecord
    mapping(address => mapping(ComplianceType => ComplianceRecord)) public complianceRecords;
    
    // Worker => WeekStartTime => WorkingHoursRecord
    mapping(address => mapping(uint256 => WorkingHoursRecord)) public workingHours;
    
    // Entity => CertificationType => Certification
    mapping(address => mapping(ComplianceType => Certification)) public certifications;

    // Compliance thresholds
    uint256 public constant MAX_WEEKLY_HOURS = 40 hours;
    uint256 public constant MAX_DAILY_HOURS = 8 hours;
    uint256 public constant MIN_REST_PERIOD = 11 hours;
    uint256 public constant MIN_WAGE = 15 ether; // In wei per hour
    uint256 public constant CERTIFICATION_VALIDITY = 365 days;

    ITimeClockOracle public timeClockOracle;

    constructor(address _timeClockOracle) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        timeClockOracle = ITimeClockOracle(_timeClockOracle);
    }

    modifier onlyVerifier() {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        _;
    }

    function verifyCompliance(
        address contractAddress,
        ComplianceType complianceType
    ) external override onlyVerifier whenNotPaused returns (bool) {
        ComplianceRecord storage record = complianceRecords[contractAddress][complianceType];
        
        bool isCompliant = _checkCompliance(contractAddress, complianceType);
        
        record.status = VerificationStatus.VERIFIED;
        record.lastVerified = block.timestamp;
        record.isCompliant = isCompliant;
        
        emit ComplianceVerified(contractAddress, complianceType, isCompliant);
        
        return isCompliant;
    }

    function submitCertification(
        bytes32 certificationId,
        bytes calldata proof
    ) external override whenNotPaused {
        require(_verifyCertificationProof(proof), "Invalid certification proof");
        
        Certification storage cert = certifications[msg.sender][ComplianceType.SAFETY_CERT];
        cert.certificationId = certificationId;
        cert.issuanceDate = block.timestamp;
        cert.expiryDate = block.timestamp + CERTIFICATION_VALIDITY;
        cert.isValid = true;
        
        emit CertificationUpdated(
            msg.sender,
            certificationId,
            cert.expiryDate
        );
    }

    function checkWorkingHours(
        address worker,
        uint256 weekStartTime
    ) external view override returns (
        uint256 regularHours,
        uint256 overtimeHours
    ) {
        WorkingHoursRecord storage record = workingHours[worker][weekStartTime];
        return (record.regularHours, record.overtimeHours);
    }

    function validateMinimumWage(
        uint256 paymentAmount,
        uint256 hoursWorked
    ) external view override returns (bool) {
        if (hoursWorked == 0) return true;
        uint256 hourlyRate = paymentAmount / hoursWorked;
        return hourlyRate >= MIN_WAGE;
    }

    function getComplianceStatus(
        address contractAddress,
        ComplianceType complianceType
    ) external view override returns (
        VerificationStatus status,
        uint256 lastVerified,
        bool isCompliant
    ) {
        ComplianceRecord storage record = complianceRecords[contractAddress][complianceType];
        return (
            record.status,
            record.lastVerified,
            record.isCompliant
        );
    }

    function isInsuranceValid(
        address worker
    ) external view override returns (bool) {
        Certification storage insurance = certifications[worker][ComplianceType.INSURANCE];
        return insurance.isValid && block.timestamp <= insurance.expiryDate;
    }

    // Internal functions
    function _checkCompliance(
        address contractAddress,
        ComplianceType complianceType
    ) internal view returns (bool) {
        if (complianceType == ComplianceType.WORKING_HOURS) {
            return _checkWorkingHoursCompliance(contractAddress);
        } else if (complianceType == ComplianceType.MINIMUM_WAGE) {
            return _checkWageCompliance(contractAddress);
        } else if (complianceType == ComplianceType.REST_PERIODS) {
            return _checkRestPeriods(contractAddress);
        } else if (complianceType == ComplianceType.AGE_VERIFICATION) {
            return _checkAgeVerification(contractAddress);
        } else if (complianceType == ComplianceType.INSURANCE) {
            return isInsuranceValid(contractAddress);
        } else if (complianceType == ComplianceType.SAFETY_CERT) {
            return _checkSafetyCertification(contractAddress);
        }
        return false;
    }

    function _checkWorkingHoursCompliance(address worker) internal view returns (bool) {
        uint256 currentWeekStart = block.timestamp - (block.timestamp % 1 weeks);
        WorkingHoursRecord storage record = workingHours[worker][currentWeekStart];
        
        return record.regularHours <= MAX_WEEKLY_HOURS;
    }

    function _checkWageCompliance(address contractAddress) internal view returns (bool) {
        // Implementation depends on payment structure
        return true;
    }

    function _checkRestPeriods(address worker) internal view returns (bool) {
        // Check time between shifts
        return true;
    }

    function _checkAgeVerification(address contractAddress) internal view returns (bool) {
        // Implementation of age verification logic
        return true;
    }

    function _checkSafetyCertification(address contractAddress) internal view returns (bool) {
        // Implementation of safety certification logic
        return true;
    }

    function _verifyCertificationProof(bytes calldata proof) internal pure returns (bool) {
        // Implement certification verification logic
        return true;
    }

    // Admin functions
    function setMinimumWage(uint256 newMinWage) external onlyRole(ADMIN_ROLE) {
        // Update minimum wage
    }

    function updateWorkingHoursLimits(
        uint256 newWeeklyLimit,
        uint256 newDailyLimit
    ) external onlyRole(ADMIN_ROLE) {
        // Update working hours limits
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}