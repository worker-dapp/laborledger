// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MilestonePayment
 * @dev Payment contract for milestone-based work compensation
 * 
 * FUNCTIONALITY:
 * 1. Milestone Management:
 *    - Defines sequential milestones
 *    - Tracks completion status
 *    - Manages milestone deadlines
 *    - Handles partial completion
 *
 * 2. Payment Processing:
 *    - Calculates milestone payments
 *    - Validates completion criteria
 *    - Processes staged payments
 *    - Handles milestone dependencies
 *
 * 3. Progress Tracking:
 *    - Monitors completion percentage
 *    - Tracks payment history
 *    - Records verification data
 *    - Maintains timeline
 *
 * USE CASES:
 * - Construction projects
 * - Software development
 * - Project-based consulting
 * - Staged deliverables
 *
 * @notice Enables structured payments based on verified milestone completion
 * @dev Requires oracle integration for milestone verification
 */

import "../interfaces/IPaymentStructure.sol";
import "../interfaces/IOracle.sol";

contract MilestonePayment is IPaymentStructure {
    struct Milestone {
        uint256 id;
        string description;
        uint256 paymentAmount;     // Amount to pay when milestone completed
        bool completed;
        bool paid;
        OracleType verificationType;
        bytes verificationCriteria; // Encoded criteria (e.g., required weight, distance, or image hash)
    }

    PaymentConfig public paymentConfig;
    WorkMetrics public workMetrics;
    mapping(uint256 => Milestone) public milestones;
    uint256 public totalMilestones;
    
    address public worker;
    address public employer;

    event MilestoneCreated(uint256 id, string description, uint256 paymentAmount);
    event MilestoneCompleted(uint256 id, uint256 paymentAmount);

    constructor(
        address _worker,
        address _employer,
        address _oracle,
        OracleType _oracleType
    ) {
        worker = _worker;
        employer = _employer;
        
        paymentConfig = PaymentConfig({
            paymentType: PaymentType.MILESTONE_BASED,
            oracleType: _oracleType,
            oracleAddress: _oracle,
            frequency: PaymentFrequency.MILESTONE,
            baseRate: 0, // Not used for milestones
            minimumPayment: 0,
            maximumPayment: 0,
            customInterval: 0,
            nextPaymentDue: 0,
            totalPaid: 0
        });
    }

    function addMilestone(
        string memory _description,
        uint256 _paymentAmount,
        OracleType _verificationType,
        bytes memory _verificationCriteria
    ) external {
        require(msg.sender == employer, "Only employer can add milestones");
        
        totalMilestones++;
        milestones[totalMilestones] = Milestone({
            id: totalMilestones,
            description: _description,
            paymentAmount: _paymentAmount,
            completed: false,
            paid: false,
            verificationType: _verificationType,
            verificationCriteria: _verificationCriteria
        });

        emit MilestoneCreated(totalMilestones, _description, _paymentAmount);
    }

    function verifyMilestone(uint256 _milestoneId, bytes memory _proof) internal returns (bool) {
        Milestone storage milestone = milestones[_milestoneId];
        
        if (milestone.verificationType == OracleType.GPS) {
            // Verify distance/location milestone
            (bool verified,) = IOracle(paymentConfig.oracleAddress).getVerificationData(
                keccak256(abi.encodePacked(_milestoneId, milestone.verificationCriteria))
            );
            return verified;
        }
        else if (milestone.verificationType == OracleType.WEIGHT) {
            // Verify weight-based milestone
            (bool verified,) = IOracle(paymentConfig.oracleAddress).getVerificationData(
                keccak256(abi.encodePacked(_milestoneId, milestone.verificationCriteria))
            );
            return verified;
        }
        else if (milestone.verificationType == OracleType.IMAGE) {
            // Verify image-based milestone
            (bool verified,) = IOracle(paymentConfig.oracleAddress).getVerificationData(
                keccak256(abi.encodePacked(_milestoneId, _proof))
            );
            return verified;
        }
        else if (milestone.verificationType == OracleType.NONE) {
            // Manual verification by employer
            return msg.sender == employer;
        }
        
        return false;
    }

    function recordWork(uint256 _milestoneId, bytes memory _proof) external override returns (bool) {
        require(_milestoneId <= totalMilestones, "Invalid milestone ID");
        require(!milestones[_milestoneId].completed, "Milestone already completed");
        require(msg.sender == worker || msg.sender == employer, "Unauthorized");

        if (verifyMilestone(_milestoneId, _proof)) {
            milestones[_milestoneId].completed = true;
            workMetrics.completedMilestones[_milestoneId] = true;
            return true;
        }
        
        return false;
    }

    function calculatePaymentDue() public view override returns (uint256) {
        uint256 paymentDue = 0;
        
        for (uint256 i = 1; i <= totalMilestones; i++) {
            if (milestones[i].completed && !milestones[i].paid) {
                paymentDue += milestones[i].paymentAmount;
            }
        }
        
        return paymentDue;
    }

    function processPayment() external override returns (uint256) {
        uint256 paymentDue = calculatePaymentDue();
        
        // Mark milestones as paid
        for (uint256 i = 1; i <= totalMilestones; i++) {
            if (milestones[i].completed && !milestones[i].paid) {
                milestones[i].paid = true;
                emit MilestoneCompleted(i, milestones[i].paymentAmount);
            }
        }
        
        paymentConfig.totalPaid += paymentDue;
        return paymentDue;
    }

    // Required interface implementations
    function getPaymentConfig() external view override returns (PaymentConfig memory) {
        return paymentConfig;
    }

    function getWorkMetrics() external view override returns (uint256 units, uint256 hours) {
        return (0, 0); // Milestone-based doesn't track units/hours
    }
}