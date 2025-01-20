// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IEscrow.sol";
import "../interfaces/IArbitration.sol";

/**
 * @title Escrow
 * @dev Manages secure payment holding and conditional releases for work contracts
 * 
 * FUNCTIONALITY:
 * 1. Payment Management:
 *    - Secure fund holding
 *    - Conditional releases
 *    - Partial payments
 *    - Dispute locks
 *
 * 2. Security Features:
 *    - Multi-signature releases
 *    - Timelock mechanisms
 *    - Dispute protection
 *    - Emergency recovery
 *
 * 3. Payment Tracking:
 *    - Deposit history
 *    - Release records
 *    - Status monitoring
 *    - Balance management
 *
 * INTEGRATION POINTS:
 * - WorkContract: Payment operations
 * - ArbitrationRegistry: Dispute handling
 * - Payment modules: Release conditions
 */

contract Escrow is IEscrow {
    struct Payment {
        uint256 amount;
        address depositor;
        uint256 depositTime;
        PaymentStatus status;
        bool isDisputed;
        mapping(address => bool) hasApproved;
    }

    mapping(bytes32 => Payment) public payments;
    IArbitration public arbitrationSystem;
    
    uint256 public constant RELEASE_TIMEOUT = 30 days;
    uint256 public constant DISPUTE_WINDOW = 7 days;

    event ApprovalGranted(bytes32 indexed paymentId, address approver);
    event TimeoutStarted(bytes32 indexed paymentId, uint256 releaseTime);

    modifier onlyActivePayment(bytes32 paymentId) {
        require(payments[paymentId].amount > 0, "Payment does not exist");
        require(payments[paymentId].status == PaymentStatus.HELD, "Invalid payment status");
        _;
    }

    constructor(address _arbitrationSystem) {
        arbitrationSystem = IArbitration(_arbitrationSystem);
    }

    function deposit(bytes32 paymentId) external payable override {
        require(msg.value > 0, "Amount must be positive");
        require(payments[paymentId].amount == 0, "Payment ID already exists");

        Payment storage payment = payments[paymentId];
        payment.amount = msg.value;
        payment.depositor = msg.sender;
        payment.depositTime = block.timestamp;
        payment.status = PaymentStatus.HELD;

        emit PaymentDeposited(paymentId, msg.value);
    }

    function release(
        bytes32 paymentId,
        address recipient,
        uint256 amount
    ) external override onlyActivePayment(paymentId) {
        Payment storage payment = payments[paymentId];
        require(!payment.isDisputed, "Payment is disputed");
        require(amount <= payment.amount, "Insufficient funds");
        require(recipient != address(0), "Invalid recipient");

        // If sender is depositor, mark their approval
        if (msg.sender == payment.depositor) {
            payment.hasApproved[msg.sender] = true;
            emit ApprovalGranted(paymentId, msg.sender);
        }

        // Check if release conditions are met
        bool canRelease = payment.hasApproved[payment.depositor] ||
                         block.timestamp >= payment.depositTime + RELEASE_TIMEOUT;

        require(canRelease, "Release conditions not met");

        // Process release
        if (amount == payment.amount) {
            payment.status = PaymentStatus.RELEASED;
        }
        payment.amount -= amount;

        // Transfer funds
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit PaymentReleased(paymentId, recipient, amount);
    }

    function disputePayment(bytes32 paymentId) 
        external 
        override 
        onlyActivePayment(paymentId) 
    {
        Payment storage payment = payments[paymentId];
        require(!payment.isDisputed, "Already disputed");
        require(
            block.timestamp <= payment.depositTime + DISPUTE_WINDOW,
            "Dispute window closed"
        );

        payment.isDisputed = true;
        payment.status = PaymentStatus.DISPUTED;

        emit PaymentDisputed(paymentId);
    }

    function refund(bytes32 paymentId) 
        external 
        override 
        onlyActivePayment(paymentId) 
    {
        Payment storage payment = payments[paymentId];
        require(msg.sender == payment.depositor, "Only depositor can refund");
        require(
            block.timestamp >= payment.depositTime + RELEASE_TIMEOUT,
            "Timeout not reached"
        );

        uint256 amount = payment.amount;
        payment.amount = 0;
        payment.status = PaymentStatus.REFUNDED;

        (bool success, ) = payment.depositor.call{value: amount}("");
        require(success, "Transfer failed");

        emit PaymentRefunded(paymentId);
    }

    function getPaymentStatus(bytes32 paymentId)
        external
        view
        override
        returns (
            PaymentStatus status,
            uint256 amount,
            address depositor,
            uint256 depositTime
        )
    {
        Payment storage payment = payments[paymentId];
        return (
            payment.status,
            payment.amount,
            payment.depositor,
            payment.depositTime
        );
    }

    function getBalance(bytes32 paymentId) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return payments[paymentId].amount;
    }

    // Emergency recovery function
    function emergencyRelease(bytes32 paymentId) 
        external 
        onlyActivePayment(paymentId) 
    {
        Payment storage payment = payments[paymentId];
        require(payment.isDisputed, "Not disputed");
        
        // Get arbitration result
        (uint8 decision, , bool isComplete) = arbitrationSystem.getVotingResult(paymentId);
        require(isComplete, "Arbitration not complete");

        uint256 amount = (payment.amount * decision) / 100;
        payment.amount = 0;
        payment.status = PaymentStatus.RELEASED;

        // Transfer according to arbitration decision
        (bool success, ) = payment.depositor.call{value: payment.amount - amount}("");
        require(success, "Depositor transfer failed");
        
        // Transfer to recipient
        (success, ) = msg.sender.call{value: amount}("");
        require(success, "Recipient transfer failed");

        emit PaymentReleased(paymentId, msg.sender, amount);
    }

    receive() external payable {
        revert("Use deposit function");
    }
}