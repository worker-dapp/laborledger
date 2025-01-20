// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IEscrow
 * @dev Interface for managing secure payment holding and releases
 * 
 * Defines functionality for:
 * - Payment deposits and holds
 * - Conditional releases
 * - Dispute-triggered locks
 * - Multi-party releases
 */

interface IEscrow {
    enum PaymentStatus {
        EMPTY,
        HELD,
        RELEASED,
        DISPUTED,
        REFUNDED
    }

    event PaymentDeposited(bytes32 indexed paymentId, uint256 amount);
    event PaymentReleased(bytes32 indexed paymentId, address recipient, uint256 amount);
    event PaymentDisputed(bytes32 indexed paymentId);
    event PaymentRefunded(bytes32 indexed paymentId);

    function deposit(bytes32 paymentId) external payable;
    
    function release(
        bytes32 paymentId,
        address recipient,
        uint256 amount
    ) external;

    function disputePayment(bytes32 paymentId) external;
    
    function refund(bytes32 paymentId) external;
    
    function getPaymentStatus(bytes32 paymentId) 
        external 
        view 
        returns (
            PaymentStatus status,
            uint256 amount,
            address depositor,
            uint256 depositTime
        );

    function getBalance(bytes32 paymentId) external view returns (uint256);
}