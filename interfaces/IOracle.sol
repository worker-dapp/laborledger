// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOracle
 * @dev Interface for Oracle contracts that verify work completion
 * 
 * Defines standard functions for work verification oracles:
 * - Verification data retrieval
 * - Oracle type identification
 * - Cost structure
 * 
 * Supports multiple verification types (GPS, image, weight, etc.)
 * while maintaining a consistent interface for the work contract.
 */

interface IOracle {
    function getVerificationData(bytes32 jobId) external view returns (bool, bytes memory);
    function getOracleType() external pure returns (string memory);
    function getCostPerVerification() external view returns (uint256);
}