// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ICompliance
 * @dev Interface for managing labor law compliance and working conditions
 * 
 * COMPLIANCE TRACKING:
 * - Working hours and overtime
 * - Minimum wage requirements
 * - Rest period enforcement
 * - Age verification
 * 
 * VERIFICATION SYSTEMS:
 * - Document validation
 * - Certification checking
 * - Insurance tracking
 * - Safety requirement monitoring
 * 
 * INTEGRATION POINTS:
 * - WorkContract: Compliance checks
 * - TimeClockOracle: Hours verification
 * - PaymentStructure: Wage compliance
 * - DAOs: Compliance governance
 * 
 * @notice Ensures work agreements meet legal and safety requirements
 */

interface ICompliance {
    enum ComplianceType {
        WORKING_HOURS,    // 0
        MINIMUM_WAGE,     // 1
        REST_PERIODS,     // 2
        AGE_VERIFICATION, // 3
        INSURANCE,        // 4
        SAFETY_CERT       // 5
    }

    enum VerificationStatus {
        PENDING,
        VERIFIED,
        REJECTED,
        EXPIRED
    }

    event ComplianceVerified(
        address indexed contractAddress,
        ComplianceType complianceType,
        bool isCompliant
    );

    event CertificationUpdated(
        address indexed entity,
        bytes32 certificationId,
        uint256 expiryDate
    );

    event ComplianceViolation(
        address indexed contractAddress,
        ComplianceType violationType,
        string details
    );

    function verifyCompliance(
        address contractAddress,
        ComplianceType complianceType
    ) external returns (bool);

    function submitCertification(
        bytes32 certificationId,
        bytes calldata proof
    ) external;

    function checkWorkingHours(
        address worker,
        uint256 weekStartTime
    ) external view returns (
        uint256 regularHours,
        uint256 overtimeHours
    );

    function validateMinimumWage(
        uint256 paymentAmount,
        uint256 hoursWorked
    ) external view returns (bool);

    function getComplianceStatus(
        address contractAddress,
        ComplianceType complianceType
    ) external view returns (
        VerificationStatus status,
        uint256 lastVerified,
        bool isCompliant
    );

    function isInsuranceValid(
        address worker
    ) external view returns (bool);
}