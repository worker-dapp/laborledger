// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPaymentStructure
 * @dev Interface for all payment type implementations including standard and custom payment structures.
 * 
 * Supports multiple payment types:
 * - SINGLE_PAYMENT: One-time payment after completion
 * - PERIODIC_TIME: Regular intervals (daily/weekly/monthly)
 * - PIECE_RATE: Based on units/weight/quantity
 * - MILESTONE_BASED: Multiple predefined achievement points
 * - CUSTOM: Flexible combinations of payment types and verification methods
 */

interface IPaymentStructure {
    enum PaymentType {
        SINGLE_PAYMENT,    // One payment at end - Manual verification
        PERIODIC_TIME,     // Daily/weekly/monthly - GPS Oracle for attendance
        PIECE_RATE,       // Based on units/weight/quantity - Weight Oracle or Image Oracle
        MILESTONE_BASED,  // Multiple predefined milestones - Multiple oracle types possible
        CUSTOM           // Custom combination of payment types and oracles
    }

    enum PaymentFrequency {
        INSTANT,        // Pay as soon as verification occurs
        DAILY,         // End of day settlement
        WEEKLY,        // Weekly settlement
        BI_WEEKLY,     // Every two weeks
        MONTHLY,       // Monthly settlement
        MILESTONE,     // Upon milestone completion
        CUSTOM         // Custom interval in seconds
    }

    enum OracleType {
        NONE,           // Manual verification
        GPS,            // Location tracking for time-based work
        WEIGHT,         // Weight measurements for piece-rate
        IMAGE,          // Visual verification for quantity/milestones
        CUSTOM          // Other verification methods
    }

    struct Milestone {
        uint256 id;
        string description;
        uint256 paymentAmount;
        bool completed;
        bool paid;
        OracleType verificationType;
        bytes verificationCriteria;
    }

    struct PaymentConfig {
        PaymentType paymentType;
        OracleType oracleType;
        address oracleAddress;
        PaymentFrequency frequency;
        uint256 baseRate;          
        uint256 minimumPayment;    
        uint256 maximumPayment;    
        uint256 customInterval;    
        uint256 nextPaymentDue;    
        uint256 totalPaid;         
    }

    struct WorkMetrics {
        uint256 unitsCompleted;    // pieces/kg/items
        uint256 hoursWorked;       // For time-based work
        mapping(uint256 => bool) completedMilestones;
    }

    // Required interface functions
    function getPaymentConfig() external view returns (PaymentConfig memory);
    function getWorkMetrics() external view returns (uint256 units, uint256 hours);
    function recordWork(uint256 amount, bytes memory proof) external returns (bool);
    function calculatePaymentDue() external view returns (uint256);
    function processPayment() external returns (uint256);

    // Optional milestone-specific functions
    function getMilestone(uint256 milestoneId) external view returns (Milestone memory);
    function getTotalMilestones() external view returns (uint256);
}
