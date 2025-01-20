// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWorkerDAO
 * @dev Interface for the WorkerDAO contract that manages worker organization,
 * welfare fund, and tiered membership system.
 *
 * CORE FUNCTIONALITY:
 * 1. Membership Management:
 *    - Tiered system (BASIC → ACTIVE → CORE → ELDER)
 *    - Activity tracking
 *    - Contribution history
 *
 * 2. Welfare Fund:
 *    - Contribution handling
 *    - Fund request processing
 *    - Tiered benefits distribution
 *
 * 3. Governance:
 *    - Arbitrator selection
 *    - Voting power by tier
 *    - Fund request approval
 *
 * 4. Activity Recording:
 *    - Contract completion
 *    - Voting participation
 *    - Arbitration service
 *    - Fund contributions
 *
 * @notice This interface ensures consistent implementation of worker
 * organization features across different versions while maintaining
 * upgrade flexibility.
 *
 * @dev Implementations should carefully handle tier transitions
 * and maintain accurate activity records for benefit calculations.
 */

interface IWorkerDAO {
    function joinDAO() external;
    function contributeToFund() external payable;
    function requestFunds(uint256 amount, string memory reason) external;
    function getWorkerArbitrators() external view returns (address[] memory);
}