// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TimeBasedPayment
 * @dev Payment contract for time-based work compensation
 * 
 * FUNCTIONALITY:
 * 1. Time Tracking:
 *    - Records work hours
 *    - Validates time entries
 *    - Manages work periods
 *    - Tracks overtime
 *
 * 2. Rate Management:
 *    - Hourly rate calculation
 *    - Overtime multipliers
 *    - Holiday rate adjustments
 *    - Rate updates
 *
 * 3. Payment Processing:
 *    - Regular interval payments
 *    - Overtime calculations
 *    - Bonus processing
 *    - Payment history
 *
 * USE CASES:
 * - Hourly labor
 * - Consulting work
 * - Shift-based work
 * - Professional services
 *
 * @notice Enables accurate compensation based on verified work hours
 * @dev Requires oracle integration for time verification
 */

import "../interfaces/IPaymentStructure.sol";
import "../interfaces/IOracle.sol";

contract TimeBasedPayment is IPaymentStructure {
    PaymentConfig public config;
    
    struct TimeRecord {
        uint256 startTime;
        uint256 endTime;
        uint256 hoursWorked;
        bool verified;
        bool paid;
    }
    
    mapping(address => TimeRecord[]) public timeRecords;
    
    constructor(
        uint256 _hourlyRate,
        PaymentFrequency _frequency,
        uint256 _customInterval
    ) {
        config = PaymentConfig({
            baseRate: _hourlyRate,
            minimumPayment: _hourlyRate * 4, // Minimum 4 hours
            maximumPayment: _hourlyRate * 12, // Maximum 12 hours per payment
            frequency: _frequency,
            customInterval: _customInterval,
            nextPaymentDue: calculateNextPaymentTime(block.timestamp, _frequency, _customInterval)
        });
    }

    function calculatePaymentAmount(address worker) public view returns (uint256) {
        uint256 unpaidHours = 0;
        TimeRecord[] memory records = timeRecords[worker];
        
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].verified && !records[i].paid) {
                unpaidHours += records[i].hoursWorked;
            }
        }
        
        return unpaidHours * config.baseRate;
    }

    function recordWork(uint256 _hours, bytes memory _proof) external override returns (bool) {
        require(msg.sender == worker || msg.sender == employer, "Unauthorized");
        
        if (config.oracleType == OracleType.GPS) {
            // GPS Oracle verifies worker location during claimed hours
            (bool verified,) = IOracle(config.oracleAddress).getVerificationData(bytes32(_hours));
            require(verified, "GPS verification failed");
        }
        else if (config.oracleType == OracleType.NONE) {
            // Manual time tracking - requires employer confirmation
            require(msg.sender == employer, "Manual verification requires employer confirmation");
        }

        workMetrics.hoursWorked += _hours;
        return true;
    }
}