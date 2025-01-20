// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IEmployerDAO
 * @dev Interface for the EmployerDAO contract
 * 
 * Defines the core functionality required for employer organization:
 * - Membership management
 * - Arbitrator selection
 * - Access to arbitrator list
 * 
 * This interface ensures consistent implementation across different versions
 * of the EmployerDAO and enables easy integration with other contracts.
 */

interface IEmployerDAO {
    function getEmployerArbitrators() external view returns (address[] memory);
}
