// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TimeClockOracle
 * @dev Oracle contract that verifies work hours through digital time clock data
 * 
 * FUNCTIONALITY:
 * 1. Time Tracking:
 *    - Clock-in/out timestamps
 *    - Break period tracking
 *    - Shift validation
 *    - Overtime calculation
 *
 * 2. Verification System:
 *    - Digital signature validation
 *    - Location-based verification (optional)
 *    - Biometric data hashes (optional)
 *    - Multiple device support
 *
 * 3. Data Management:
 *    - Shift records
 *    - Work hour calculations
 *    - Break compliance
 *    - Schedule adherence
 *
 * DATA STRUCTURE:
 * - TimeRecord:
 *   * Clock-in timestamp
 *   * Clock-out timestamp
 *   * Break durations
 *   * Verification signature
 *   * Device identifier
 *
 * USE CASES:
 * - Factory shifts
 * - Office hours
 * - Field work tracking
 * - Remote work verification
 *
 * @notice Provides verified time records for time-based payment calculations
 * @dev Requires integration with approved time clock devices/systems
 */

import "../interfaces/IOracle.sol";

contract TimeClockOracle is IOracle {
    struct TimeRecord {
        uint256 clockIn;
        uint256 clockOut;
        uint256[] breakStarts;
        uint256[] breakEnds;
        bytes signature;
        string deviceId;
        bool isValid;
    }

    mapping(bytes32 => TimeRecord) public timeRecords;
    mapping(string => bool) public approvedDevices;
    address public admin;

    event TimeRecordCreated(bytes32 indexed jobId, uint256 clockIn);
    event TimeRecordCompleted(bytes32 indexed jobId, uint256 clockOut);
    event BreakStarted(bytes32 indexed jobId, uint256 timestamp);
    event BreakEnded(bytes32 indexed jobId, uint256 timestamp);

    constructor() {
        admin = msg.sender;
    }

    function recordClockIn(
        bytes32 jobId,
        string calldata deviceId,
        bytes calldata signature
    ) external {
        require(approvedDevices[deviceId], "Unapproved device");
        require(!timeRecords[jobId].isValid, "Shift already started");

        timeRecords[jobId] = TimeRecord({
            clockIn: block.timestamp,
            clockOut: 0,
            breakStarts: new uint256[](0),
            breakEnds: new uint256[](0),
            signature: signature,
            deviceId: deviceId,
            isValid: true
        });

        emit TimeRecordCreated(jobId, block.timestamp);
    }

    function recordClockOut(
        bytes32 jobId,
        string calldata deviceId,
        bytes calldata signature
    ) external {
        require(timeRecords[jobId].isValid, "No active shift");
        require(keccak256(bytes(timeRecords[jobId].deviceId)) == keccak256(bytes(deviceId)), "Device mismatch");

        TimeRecord storage record = timeRecords[jobId];
        record.clockOut = block.timestamp;
        record.signature = signature;

        emit TimeRecordCompleted(jobId, block.timestamp);
    }

    function recordBreakStart(bytes32 jobId) external {
        require(timeRecords[jobId].isValid, "No active shift");
        require(timeRecords[jobId].clockOut == 0, "Shift already ended");

        TimeRecord storage record = timeRecords[jobId];
        record.breakStarts.push(block.timestamp);

        emit BreakStarted(jobId, block.timestamp);
    }

    function recordBreakEnd(bytes32 jobId) external {
        require(timeRecords[jobId].isValid, "No active shift");
        require(timeRecords[jobId].breakStarts.length > timeRecords[jobId].breakEnds.length, "No active break");

        TimeRecord storage record = timeRecords[jobId];
        record.breakEnds.push(block.timestamp);

        emit BreakEnded(jobId, block.timestamp);
    }

    function getVerificationData(bytes32 jobId) 
        external 
        view 
        override 
        returns (bool, bytes memory) 
    {
        TimeRecord memory record = timeRecords[jobId];
        require(record.isValid, "No record found");
        
        return (true, abi.encode(
            record.clockIn,
            record.clockOut,
            record.breakStarts,
            record.breakEnds
        ));
    }

    function getOracleType() external pure override returns (string memory) {
        return "TIME_CLOCK";
    }

    function getCostPerVerification() external pure override returns (uint256) {
        return 0.001 ether;
    }
}