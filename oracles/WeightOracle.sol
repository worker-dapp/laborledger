// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title WeightOracle
 * @dev Oracle contract that verifies work completion through weight measurements
 * 
 * FUNCTIONALITY:
 * 1. Weight Verification:
 *    - Records weight measurements
 *    - Validates scale signatures
 *    - Tracks measurement timestamps
 *    - Stores scale identifiers
 *
 * 2. Scale Management:
 *    - Maintains authorized scale registry
 *    - Validates scale signatures
 *    - Ensures measurement integrity
 *    - Prevents unauthorized submissions
 *
 * 3. Measurement History:
 *    - Tracks multiple measurements per job
 *    - Maintains chronological order
 *    - Links measurements to specific jobs
 *
 * DATA STRUCTURE:
 * - WeightMeasurement:
 *   * Timestamp
 *   * Weight in kilograms
 *   * Scale identifier
 *   * Cryptographic signature
 *
 * USE CASES:
 * - Agricultural produce weighing
 * - Mining output verification
 * - Recycling collection measurement
 * - Bulk material processing
 *
 * @notice This oracle enables automated verification of work through weight measurements
 * @dev Requires integration with authorized digital scales for secure measurements
 */

import "../interfaces/IOracle.sol";

contract WeightOracle is IOracle {
    struct WeightMeasurement {
        uint256 timestamp;
        uint256 weightKg;
        bytes32 scaleId;
        bytes signature;
    }
    
    mapping(bytes32 => WeightMeasurement[]) public measurements;
    mapping(bytes32 => bool) public authorizedScales;

    function recordWeight(
        bytes32 jobId,
        uint256 weight,
        bytes32 scaleId,
        bytes memory signature
    ) external {
        require(authorizedScales[scaleId], "Unauthorized scale");
        require(verifyScaleSignature(scaleId, weight, signature), "Invalid signature");
        
        measurements[jobId].push(WeightMeasurement({
            timestamp: block.timestamp,
            weightKg: weight,
            scaleId: scaleId,
            signature: signature
        }));
    }

    function getVerificationData(bytes32 jobId) external view override returns (bool, bytes memory) {
        // Return latest weight measurement
        WeightMeasurement[] memory jobMeasurements = measurements[jobId];
        if (jobMeasurements.length == 0) return (false, "");
        
        return (true, abi.encode(jobMeasurements[jobMeasurements.length - 1]));
    }

    // Add these new interface functions
    function getOracleType() external pure override returns (string memory) {
        return "WEIGHT";
    }

    function getCostPerVerification() external view override returns (uint256) {
        return 0.001 ether; // Or whatever cost you want to set
    }
}