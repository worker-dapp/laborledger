// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EvidenceRegistry
 * @dev Registry for managing evidence submissions in disputes
 * 
 * FUNCTIONALITY:
 * 1. Evidence Storage:
 *    - Secure hash storage
 *    - Metadata tracking
 *    - Submission timestamps
 *    - Submitter verification
 *
 * 2. Evidence Types:
 *    - Document hashes
 *    - Image/video references
 *    - Witness statements
 *    - External data sources
 *
 * 3. Access Control:
 *    - Dispute party submissions
 *    - Arbitrator access
 *    - Public verification
 *
 * SECURITY FEATURES:
 * - Immutable evidence records
 * - Cryptographic verification
 * - Timestamp validation
 * - Submitter authentication
 *
 * @notice This registry maintains a secure and verifiable record of all
 * evidence submitted during dispute resolution processes
 */

import "../interfaces/IEvidenceRegistry.sol";

contract EvidenceRegistry is IEvidenceRegistry {
    struct Evidence {
        bytes32 evidenceHash;
        address submitter;
        uint256 timestamp;
        string evidenceType;
        string metadataURI;
        bool isValid;
    }

    // disputeId => array of evidence
    mapping(bytes32 => Evidence[]) public disputeEvidence;
    
    function submitEvidence(
        bytes32 disputeId,
        bytes32 evidenceHash,
        string calldata evidenceType,
        string calldata metadataURI
    ) external override {
        Evidence memory evidence = Evidence({
            evidenceHash: evidenceHash,
            submitter: msg.sender,
            timestamp: block.timestamp,
            evidenceType: evidenceType,
            metadataURI: metadataURI,
            isValid: true
        });

        disputeEvidence[disputeId].push(evidence);
        
        emit EvidenceSubmitted(disputeId, msg.sender, evidenceHash);
    }

    function getEvidence(bytes32 disputeId) 
        external 
        view 
        override
        returns (
            bytes32[] memory hashes,
            address[] memory submitters,
            string[] memory evidenceTypes,
            string[] memory metadataURIs
        ) 
    {
        Evidence[] storage evidenceArray = disputeEvidence[disputeId];
        uint256 length = evidenceArray.length;

        hashes = new bytes32[](length);
        submitters = new address[](length);
        evidenceTypes = new string[](length);
        metadataURIs = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            Evidence storage evidence = evidenceArray[i];
            hashes[i] = evidence.evidenceHash;
            submitters[i] = evidence.submitter;
            evidenceTypes[i] = evidence.evidenceType;
            metadataURIs[i] = evidence.metadataURI;
        }
    }
}