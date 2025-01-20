// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CustomPayment
 * @dev A flexible payment contract that allows combinations of different payment types and verification methods.
 * 
 * This contract enables complex payment scenarios such as:
 * - Dual oracle verification (e.g., weight + GPS location)
 * - Hybrid payment calculations (e.g., base hourly rate + piece rate bonuses)
 * - Custom payment intervals and verification rules
 * 
 * Example use cases:
 * - Plantation workers (weight verification + location tracking)
 * - Delivery workers (distance traveled + proof of delivery)
 * - Factory workers (time tracking + production quotas)
 */

import "../interfaces/IPaymentStructure.sol";
import "../interfaces/IOracle.sol";

contract CustomPayment is IPaymentStructure {
    struct CustomPaymentRule {
        PaymentType baseType;          // The primary payment type
        OracleType primaryOracle;      // Primary verification method
        OracleType secondaryOracle;    // Optional secondary verification
        uint256 customInterval;        // Custom payment interval if needed
        bytes customCriteria;          // Any additional verification criteria
        bool requiresDualVerification; // Whether both oracles must verify
    }

    PaymentConfig public paymentConfig;
    WorkMetrics public workMetrics;
    CustomPaymentRule public paymentRule;
    
    address public worker;
    address public employer;
    address public primaryOracleAddress;
    address public secondaryOracleAddress;

    constructor(
        address _worker,
        address _employer,
        CustomPaymentRule memory _rule,
        address _primaryOracle,
        address _secondaryOracle,
        uint256 _baseRate,
        uint256 _minimumPayment,
        uint256 _maximumPayment
    ) {
        worker = _worker;
        employer = _employer;
        paymentRule = _rule;
        primaryOracleAddress = _primaryOracle;
        secondaryOracleAddress = _secondaryOracle;

        paymentConfig = PaymentConfig({
            paymentType: PaymentType.CUSTOM,      // Add CUSTOM to PaymentType enum
            oracleType: _rule.primaryOracle,
            oracleAddress: _primaryOracle,
            frequency: PaymentFrequency.CUSTOM,
            baseRate: _baseRate,
            minimumPayment: _minimumPayment,
            maximumPayment: _maximumPayment,
            customInterval: _rule.customInterval,
            nextPaymentDue: block.timestamp + _rule.customInterval,
            totalPaid: 0
        });
    }

    function recordWork(uint256 _amount, bytes memory _proof) external override returns (bool) {
        require(msg.sender == worker || msg.sender == employer, "Unauthorized");

        bool verified = verifyWork(_amount, _proof);
        require(verified, "Work verification failed");

        // Update metrics based on base payment type
        if (paymentRule.baseType == PaymentType.PIECE_RATE) {
            workMetrics.unitsCompleted += _amount;
        } else if (paymentRule.baseType == PaymentType.PERIODIC_TIME) {
            workMetrics.hoursWorked += _amount;
        }

        return true;
    }

    function verifyWork(uint256 _amount, bytes memory _proof) internal returns (bool) {
        // Primary oracle verification
        bool primaryVerified = true;
        if (primaryOracleAddress != address(0)) {
            (primaryVerified,) = IOracle(primaryOracleAddress).getVerificationData(
                keccak256(abi.encodePacked(_amount, _proof))
            );
        }

        // Secondary oracle verification if required
        bool secondaryVerified = true;
        if (paymentRule.requiresDualVerification && secondaryOracleAddress != address(0)) {
            (secondaryVerified,) = IOracle(secondaryOracleAddress).getVerificationData(
                keccak256(abi.encodePacked(_amount, _proof))
            );
        }

        return primaryVerified && secondaryVerified;
    }

    function calculatePaymentDue() public view override returns (uint256) {
        uint256 paymentDue;
        
        if (paymentRule.baseType == PaymentType.PIECE_RATE) {
            paymentDue = workMetrics.unitsCompleted * paymentConfig.baseRate;
        } else if (paymentRule.baseType == PaymentType.PERIODIC_TIME) {
            paymentDue = workMetrics.hoursWorked * paymentConfig.baseRate;
        }

        require(paymentDue >= paymentConfig.minimumPayment, "Below minimum payment");
        require(paymentDue <= paymentConfig.maximumPayment, "Exceeds maximum payment");
        
        return paymentDue;
    }

    function processPayment() external override returns (uint256) {
        require(block.timestamp >= paymentConfig.nextPaymentDue, "Payment not due yet");
        
        uint256 paymentDue = calculatePaymentDue();
        paymentConfig.totalPaid += paymentDue;
        paymentConfig.nextPaymentDue = block.timestamp + paymentConfig.customInterval;
        
        return paymentDue;
    }

    function getPaymentConfig() external view override returns (PaymentConfig memory) {
        return paymentConfig;
    }

    function getWorkMetrics() external view override returns (uint256 units, uint256 hours) {
        return (workMetrics.unitsCompleted, workMetrics.hoursWorked);
    }

    // Optional milestone functions
    function getMilestone(uint256) external pure override returns (Milestone memory) {
        revert("Milestones not supported in custom payment");
    }

    function getTotalMilestones() external pure override returns (uint256) {
        return 0;
    }
}
