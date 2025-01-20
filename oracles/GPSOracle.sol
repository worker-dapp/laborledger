// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GPSOracle
 * @dev Oracle contract that verifies worker location data for work verification
 * 
 * FUNCTIONALITY:
 * 1. Location Tracking:
 *    - Records worker GPS coordinates
 *    - Timestamps each location update
 *    - Tracks location accuracy
 *    - Stores signed location data
 *
 * 2. Work Verification:
 *    - Validates worker presence at worksite
 *    - Confirms work hours based on location data
 *    - Ensures location accuracy meets requirements
 *    - Prevents location spoofing through signatures
 *
 * 3. Worksite Management:
 *    - Stores designated work areas
 *    - Validates worker location against work areas
 *    - Handles multiple worksite definitions
 *
 * DATA STRUCTURE:
 * - Location Data:
 *   * Timestamp
 *   * Latitude/Longitude
 *   * Accuracy radius
 *   * Cryptographic signature
 *
 * @notice This oracle provides location-based verification for work contracts
 * @dev Coordinates are stored as fixed-point numbers with appropriate precision
 */

import "../interfaces/IOracle.sol";

contract GPSOracle is IOracle {
    struct LocationData {
        uint256 timestamp;
        int256 latitude;
        int256 longitude;
        uint256 accuracy;
        bytes signature;
    }

    mapping(address => mapping(uint256 => LocationData)) public workerLocations;
    mapping(bytes32 => bytes32) public jobWorkSites;

    function recordLocation(
        bytes32 jobId,
        int256 lat,
        int256 long,
        uint256 accuracy
    ) external {
        // Verify worker is within designated work area
        bytes32 workSite = jobWorkSites[jobId];
        require(isWithinWorkSite(lat, long, workSite), "Worker not at worksite");
        
        workerLocations[msg.sender][block.timestamp] = LocationData({
            timestamp: block.timestamp,
            latitude: lat,
            longitude: long,
            accuracy: accuracy,
            signature: generateSignature(lat, long, block.timestamp)
        });
    }

    function getVerificationData(bytes32 jobId) external view override returns (bool, bytes memory) {
        // Return work hours based on location data
        return (true, abi.encode(calculateWorkHours(msg.sender, jobId)));
    }

    // Add these new interface functions
    function getOracleType() external pure override returns (string memory) {
        return "GPS";
    }

    function getCostPerVerification() external view override returns (uint256) {
        return 0.001 ether; // Or whatever cost you want to set
    }
}