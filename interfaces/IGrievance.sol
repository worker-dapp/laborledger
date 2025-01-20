// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGrievance
 * @dev Interface for the GrievanceRegistry contract that handles worker complaints
 * and dispute resolution processes.
 *
 * FUNCTIONALITY:
 * 1. Grievance Filing:
 *    - Anonymous submission system
 *    - Category-based classification
 *    - Timestamp and contract tracking
 *
 * 2. Status Tracking:
 *    - PENDING: Initial state
 *    - IN_MEDIATION: Under review
 *    - RESOLVED_SATISFACTORY: Successfully resolved
 *    - RESOLVED_UNSATISFACTORY: Unresolved issues
 *    - ESCALATED_TO_AUTHORITY: Referred to external bodies
 *
 * 3. Privacy Features:
 *    - Hashed grievance IDs
 *    - Anonymous reporting
 *    - Protected worker identity
 *
 * 4. Access Control:
 *    - Contract authorization system
 *    - Restricted update capabilities
 *    - Controlled data access
 *
 * @notice This interface ensures consistent handling of worker grievances
 * while maintaining privacy and enabling future AI integration for
 * automated mediation processes.
 */

interface IGrievanceRegistry {
    enum GrievanceStatus {
        PENDING,
        IN_MEDIATION,
        RESOLVED_SATISFACTORY,
        RESOLVED_UNSATISFACTORY,
        ESCALATED_TO_AUTHORITY
    }

    event GrievanceFiled(bytes32 indexed grievanceId, string category, address indexed workContract);
    event GrievanceStatusUpdated(bytes32 indexed grievanceId, GrievanceStatus status);
    event GrievanceResolved(bytes32 indexed grievanceId, GrievanceStatus resolution);
    event ContractAuthorized(address workContract);

    function authorizeContract(address _workContract) external;

    function fileGrievance(
        address _worker,
        string calldata _category,
        string calldata _details,
        bytes32 _salt
    ) external returns (bytes32);

    function updateGrievanceStatus(
        bytes32 _grievanceId,
        GrievanceStatus _newStatus,
        address _updater
    ) external;

    function getWorkerGrievances(address _worker) 
        external 
        view 
        returns (bytes32[] memory);

    function getGrievanceDetails(bytes32 _grievanceId) 
        external 
        view 
        returns (
            uint256 timestamp,
            string memory category,
            GrievanceStatus status,
            address workContract
        );
}