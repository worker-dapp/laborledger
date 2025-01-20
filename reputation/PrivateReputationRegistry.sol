// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ReputationRegistry.sol";
import "../interfaces/IReputation.sol";
import "../interfaces/IVerifier.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title PrivateReputationRegistry
 * @dev Privacy-preserving reputation system using ZKPs
 * 
 * Allows workers to prove:
 * - Minimum score thresholds
 * - Experience levels
 * - Clean dispute history
 * Without revealing actual values
 */

contract PrivateReputationRegistry is ReputationRegistry {
    // Interface for ZKP verification
    IVerifier public verifier;
    
    // Mapping of verified proofs
    mapping(bytes32 => bool) public verifiedProofs;
    
    // Proof expiration time (1 day)
    uint256 public constant PROOF_VALIDITY_PERIOD = 1 days;
    
    // Proof types
    enum ProofType {
        MINIMUM_SCORE,
        EXPERIENCE_LEVEL,
        DISPUTE_FREE,
        COMPLETION_RATE
    }

    struct ProofRecord {
        ProofType proofType;
        uint256 timestamp;
        uint256 claimedValue;
        bool isValid;
    }

    // Worker => ProofType => ProofRecord
    mapping(address => mapping(ProofType => ProofRecord)) public proofRecords;

    event ProofSubmitted(
        address indexed worker,
        ProofType proofType,
        bytes32 proofHash
    );

    event ProofVerified(
        address indexed worker,
        ProofType proofType,
        uint256 claimedValue
    );

    constructor(address _verifier) {
        verifier = IVerifier(_verifier);
    }

    /**
     * @dev Worker submits ZKP of minimum reputation score
     * @param proof ZKP of score being above threshold
     * @param publicInputs Public inputs for verification
     * @param claimedValue The threshold being proved against
     */
    function submitScoreProof(
        bytes calldata proof,
        uint256[] calldata publicInputs,
        uint256 claimedValue
    ) external {
        require(claimedValue <= 100, "Invalid score claim");
        
        // Verify the proof
        bool isValid = verifier.verifyProof(
            proof,
            publicInputs
        );
        require(isValid, "Invalid proof");

        // Record the proof
        bytes32 proofHash = keccak256(abi.encodePacked(
            msg.sender,
            ProofType.MINIMUM_SCORE,
            claimedValue,
            block.timestamp
        ));

        proofRecords[msg.sender][ProofType.MINIMUM_SCORE] = ProofRecord({
            proofType: ProofType.MINIMUM_SCORE,
            timestamp: block.timestamp,
            claimedValue: claimedValue,
            isValid: true
        });

        verifiedProofs[proofHash] = true;
        
        emit ProofSubmitted(msg.sender, ProofType.MINIMUM_SCORE, proofHash);
        emit ProofVerified(msg.sender, ProofType.MINIMUM_SCORE, claimedValue);
    }

    /**
     * @dev Worker proves experience level without revealing exact contract count
     */
    function proveExperienceLevel(
        bytes calldata proof,
        uint256[] calldata publicInputs,
        uint256 claimedLevel
    ) external {
        require(claimedLevel <= 5, "Invalid level claim"); // Levels 1-5
        
        bool isValid = verifier.verifyProof(proof, publicInputs);
        require(isValid, "Invalid proof");

        proofRecords[msg.sender][ProofType.EXPERIENCE_LEVEL] = ProofRecord({
            proofType: ProofType.EXPERIENCE_LEVEL,
            timestamp: block.timestamp,
            claimedValue: claimedLevel,
            isValid: true
        });

        emit ProofVerified(msg.sender, ProofType.EXPERIENCE_LEVEL, claimedLevel);
    }

    /**
     * @dev Employer verifies worker's claims
     */
    function verifyWorkerClaims(
        address worker,
        ProofType proofType,
        uint256 minimumRequired
    ) external view returns (bool) {
        ProofRecord memory record = proofRecords[worker][proofType];
        
        require(record.isValid, "No valid proof found");
        require(
            block.timestamp <= record.timestamp + PROOF_VALIDITY_PERIOD,
            "Proof expired"
        );

        return record.claimedValue >= minimumRequired;
    }

    /**
     * @dev Get proof status without revealing actual values
     */
    function getProofStatus(
        address worker,
        ProofType proofType
    ) external view returns (
        bool isValid,
        uint256 timestamp
    ) {
        ProofRecord memory record = proofRecords[worker][proofType];
        return (record.isValid, record.timestamp);
    }

    /**
     * @dev Override score update to maintain privacy
     */
    function updateScore(
        address entity,
        ReputationType entityType,
        ScoreFactors factor,
        uint256 score,
        bytes calldata proof
    ) external override onlyUpdater {
        super.updateScore(entity, entityType, factor, score, proof);
        
        // Invalidate existing proofs when score changes
        ProofRecord storage record = proofRecords[entity][ProofType.MINIMUM_SCORE];
        record.isValid = false;
    }
}