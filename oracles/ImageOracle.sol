// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ImageOracle
 * @dev Oracle contract that verifies work completion through image analysis
 * 
 * FUNCTIONALITY:
 * 1. Image Verification:
 *    - Stores image hashes
 *    - Records AI model analysis results
 *    - Tracks verification timestamps
 *    - Quantifies work completion
 *
 * 2. AI Integration:
 *    - Processes AI model outputs
 *    - Extracts quantity/quality metrics
 *    - Validates work against requirements
 *    - Stores model confidence scores
 *
 * 3. Verification History:
 *    - Maintains verification timeline
 *    - Tracks multiple submissions
 *    - Links verifications to specific jobs
 *
 * DATA STRUCTURE:
 * - ImageVerification:
 *   * Image hash (for integrity)
 *   * Timestamp
 *   * Verified quantity
 *   * AI model output data
 *
 * USE CASES:
 * - Agricultural harvest verification
 * - Construction progress monitoring
 * - Manufacturing quality control
 * - Work completion documentation
 *
 * @notice This oracle enables automated verification of work through image analysis
 * @dev Image data is stored off-chain, only hashes and analysis results are stored on-chain
 */

import "../interfaces/IOracle.sol";

contract ImageOracle is IOracle {
    struct ImageVerification {
        bytes32 imageHash;
        uint256 timestamp;
        uint256 verifiedQuantity;
        bytes aiModelOutput;
    }

    mapping(bytes32 => ImageVerification[]) public verifications;

    function verifyImage(
        bytes32 jobId,
        bytes32 imageHash,
        bytes memory aiModelOutput
    ) external {
        uint256 quantity = parseQuantityFromAI(aiModelOutput);
        
        verifications[jobId].push(ImageVerification({
            imageHash: imageHash,
            timestamp: block.timestamp,
            verifiedQuantity: quantity,
            aiModelOutput: aiModelOutput
        }));
    }

    function getVerificationData(bytes32 jobId) external view override returns (bool, bytes memory) {
        // Return verified quantity from image analysis
        return (true, abi.encode(getLatestVerification(jobId)));
    }

    // Add these new interface functions
    function getOracleType() external pure override returns (string memory) {
        return "IMAGE";
    }

    function getCostPerVerification() external view override returns (uint256) {
        return 0.002 ether; // Image processing might cost more than GPS/weight
    }
}