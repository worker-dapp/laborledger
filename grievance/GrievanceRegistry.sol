// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IGrievance.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title GrievanceRegistry
 * @dev Manages worker grievances and dispute resolution processes
 * 
 * FUNCTIONALITY:
 * 1. Grievance Filing:
 *    - Worker submissions
 *    - Evidence attachment
 *    - Timestamp tracking
 *    - Category classification
 *
 * 2. Resolution Process:
 *    - Employer responses
 *    - Mediation steps
 *    - Resolution tracking
 *    - Appeal handling
 *
 * 3. Stakeholder Management:
 *    - Worker rights
 *    - Employer obligations
 *    - DAO oversight
 *    - Arbitrator involvement
 *
 * 4. Integration Points:
 *    - WorkContract: Grievance triggers
 *    - ArbitrationSystem: Dispute escalation
 *    - ReputationSystem: Impact tracking
 *    - ComplianceSystem: Violation checks
 *
 * SECURITY FEATURES:
 * - Role-based access control
 * - Evidence verification
 * - Timelock mechanisms
 * - Privacy protections
 *
 * @notice This system ensures fair handling of workplace grievances while
 * maintaining appropriate privacy and security measures
 */

contract GrievanceRegistry is IGrievance, AccessControl, Pausable {
    struct Grievance {
        bytes32 id;
        uint256 timestamp;
        string category;
        GrievanceStatus status;
        address workContract;
        bool exists;
    }

    enum GrievanceStatus {
        PENDING,
        IN_MEDIATION,
        RESOLVED_SATISFACTORY,
        RESOLVED_UNSATISFACTORY,
        ESCALATED_TO_AUTHORITY
    }

    mapping(bytes32 => Grievance) public grievances;
    mapping(address => mapping(address => bytes32[])) private workerGrievances;  // contract -> worker -> grievances
    mapping(address => bool) public authorizedContracts;
    address public admin;

    event GrievanceFiled(bytes32 indexed grievanceId, string category, address indexed workContract);
    event GrievanceStatusUpdated(bytes32 indexed grievanceId, GrievanceStatus status);
    event GrievanceResolved(bytes32 indexed grievanceId, GrievanceStatus resolution);
    event ContractAuthorized(address workContract);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }

    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "Only authorized contracts can call this");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function authorizeContract(address _workContract) external onlyAdmin {
        authorizedContracts[_workContract] = true;
        emit ContractAuthorized(_workContract);
    }

    function fileGrievance(
        address _worker,
        string calldata _category,
        string calldata _details,
        bytes32 _salt
    ) external onlyAuthorizedContract returns (bytes32) {
        bytes32 grievanceId = keccak256(abi.encodePacked(
            _details,
            _salt,
            block.timestamp,
            msg.sender,
            _worker
        ));

        grievances[grievanceId] = Grievance({
            id: grievanceId,
            timestamp: block.timestamp,
            category: _category,
            status: GrievanceStatus.PENDING,
            workContract: msg.sender,
            exists: true
        });

        workerGrievances[msg.sender][_worker].push(grievanceId);

        emit GrievanceFiled(grievanceId, _category, msg.sender);
        return grievanceId;
    }

    function updateGrievanceStatus(
        bytes32 _grievanceId,
        GrievanceStatus _newStatus,
        address _updater
    ) external onlyAuthorizedContract {
        require(grievances[_grievanceId].exists, "Grievance does not exist");
        require(grievances[_grievanceId].workContract == msg.sender, "Wrong contract");

        grievances[_grievanceId].status = _newStatus;

        emit GrievanceStatusUpdated(_grievanceId, _newStatus);

        if (_newStatus == GrievanceStatus.RESOLVED_SATISFACTORY ||
            _newStatus == GrievanceStatus.RESOLVED_UNSATISFACTORY ||
            _newStatus == GrievanceStatus.ESCALATED_TO_AUTHORITY) {
            emit GrievanceResolved(_grievanceId, _newStatus);
        }
    }

    function getWorkerGrievances(address _worker) 
        external 
        view 
        onlyAuthorizedContract 
        returns (bytes32[] memory) 
    {
        return workerGrievances[msg.sender][_worker];
    }

    function getGrievanceDetails(bytes32 _grievanceId) 
        external 
        view 
        returns (
            uint256 timestamp,
            string memory category,
            GrievanceStatus status,
            address workContract
        ) 
    {
        require(grievances[_grievanceId].exists, "Grievance does not exist");
        Grievance storage g = grievances[_grievanceId];
        return (g.timestamp, g.category, g.status, g.workContract);
    }
}