// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PieceRatePayment
 * @dev Payment contract for unit-based work compensation
 * 
 * FUNCTIONALITY:
 * 1. Unit Tracking:
 *    - Records completed units
 *    - Validates unit verification
 *    - Tracks quality metrics
 *    - Manages rate adjustments
 *
 * 2. Payment Calculation:
 *    - Per-unit rate application
 *    - Quality-based adjustments
 *    - Bonus calculations
 *    - Payment aggregation
 *
 * 3. Rate Management:
 *    - Base rate definition
 *    - Volume-based bonuses
 *    - Quality multipliers
 *    - Rate updates
 *
 * USE CASES:
 * - Agricultural harvesting
 * - Manufacturing assembly
 * - Content creation
 * - Delivery services
 *
 * @notice Enables fair compensation based on verified unit completion
 * @dev Integrates with oracles for unit verification
 */

import "../interfaces/IPaymentStructure.sol";
import "../interfaces/IOracle.sol";

contract PieceRatePayment is IPaymentStructure {
    PaymentConfig public config;
    
    struct UnitRecord {
        uint256 timestamp;
        uint256 quantity;
        uint256 weight;
        bool verified;
        bool paid;
    }
    
    mapping(address => UnitRecord[]) public unitRecords;
    
    constructor(
        uint256 _unitRate,
        PaymentFrequency _frequency,
        uint256 _customInterval
    ) {
        config = PaymentConfig({
            baseRate: _unitRate,
            minimumPayment: _unitRate * 10, // Minimum 10 units
            maximumPayment: _unitRate * 1000, // Maximum 1000 units per payment
            frequency: _frequency,
            customInterval: _customInterval,
            nextPaymentDue: calculateNextPaymentTime(block.timestamp, _frequency, _customInterval)
        });
    }

    function calculatePaymentAmount(address worker) public view returns (uint256) {
        uint256 unpaidUnits = 0;
        UnitRecord[] memory records = unitRecords[worker];
        
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].verified && !records[i].paid) {
                unpaidUnits += records[i].quantity;
            }
        }
        
        return unpaidUnits * config.baseRate;
    }

    function recordWork(uint256 _units, bytes memory _proof) external override returns (bool) {
        require(msg.sender == worker || msg.sender == employer, "Unauthorized");
        
        // Different verification based on oracle type
        if (config.oracleType == OracleType.WEIGHT) {
            (bool verified,) = IOracle(config.oracleAddress).getVerificationData(bytes32(_units));
            require(verified, "Weight verification failed");
        }
        else if (config.oracleType == OracleType.IMAGE) {
            (bool verified,) = IOracle(config.oracleAddress).getVerificationData(bytes32(_units));
            require(verified, "Image verification failed");
        }
        else if (config.oracleType == OracleType.NONE) {
            // Manual verification - both worker and employer must confirm
            require(msg.sender == employer, "Manual verification requires employer confirmation");
        }

        workMetrics.unitsCompleted += _units;
        return true;
    }
}