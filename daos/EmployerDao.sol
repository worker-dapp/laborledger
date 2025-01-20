// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EmployerDAO
 * @dev A decentralized autonomous organization (DAO) for employers focused on 
 * arbitrator selection and dispute resolution.
 *
 * STRUCTURE:
 * 1. Membership:
 *    - Open to all employers
 *    - One-time registration
 *    - Equal voting rights among members
 *
 * 2. Arbitrator System:
 *    - Members can nominate arbitrators
 *    - Democratic election process
 *    - Top 5 arbitrators selected every 6 months
 *    - Performance tracking (cases handled, cases overturned)
 *
 * 3. Governance:
 *    - Regular elections every 180 days
 *    - One vote per member
 *    - Transparent arbitrator selection
 *
 * MAIN FEATURES:
 * - Arbitrator Nomination: Members can nominate trusted arbitrators
 * - Democratic Elections: Regular voting cycles for arbitrator selection
 * - Performance Tracking: Monitors arbitrator effectiveness
 * - Transparent Governance: All actions and votes are public
 * - Regular Rotation: Ensures fresh perspective in arbitration
 *
 * ELECTION PROCESS:
 * 1. Members nominate arbitrators
 * 2. Members vote for nominees
 * 3. Top 5 most voted become active arbitrators
 * 4. New election every 6 months
 *
 * @notice This contract manages employer representation in dispute resolution
 * @dev All voting periods are time-based and automated
 */

import "../interfaces/IEmployerDAO.sol";

contract EmployerDAO is IEmployerDAO {
    struct Arbitrator {
        address arbitratorAddress;
        uint256 votes;
        uint256 casesHandled;
        uint256 casesOverturned;
    }

    address[] public employerArbitrators;
    address[] public daoMembers;
    mapping(address => bool) public isDAOMember;
    mapping(address => Arbitrator) public arbitratorData;
    mapping(address => bool) public hasVotedForArbitrator;

    uint256 public lastElectionTime;
    uint256 public electionInterval = 180 days; // Elections every 6 months

    event EmployerJoinedDAO(address employer);
    event ArbitratorNominated(address arbitrator);
    event ArbitratorElected(address arbitrator);

    modifier onlyDAOMember() {
        require(isDAOMember[msg.sender], "Only DAO members can vote");
        _;
    }

    constructor() {
        lastElectionTime = block.timestamp;
    }

    function joinDAO() public {
        require(!isDAOMember[msg.sender], "Already a member");
        isDAOMember[msg.sender] = true;
        daoMembers.push(msg.sender);
        emit EmployerJoinedDAO(msg.sender);
    }

    function nominateArbitrator(address arbitrator) public onlyDAOMember {
        require(arbitrator != msg.sender, "You cannot nominate yourself");
        require(arbitratorData[arbitrator].arbitratorAddress == address(0), "Already nominated");

        arbitratorData[arbitrator] = Arbitrator({
            arbitratorAddress: arbitrator,
            votes: 0,
            casesHandled: 0,
            casesOverturned: 0
        });

        emit ArbitratorNominated(arbitrator);
    }

    function voteForArbitrator(address arbitrator) public onlyDAOMember {
        require(!hasVotedForArbitrator[msg.sender], "You have already voted");
        require(arbitratorData[arbitrator].arbitratorAddress != address(0), "Not a valid arbitrator");

        arbitratorData[arbitrator].votes++;
        hasVotedForArbitrator[msg.sender] = true;

        emit ArbitratorElected(arbitrator);
    }

    function conductElection() public {
        require(block.timestamp >= lastElectionTime + electionInterval, "Election period has not arrived");

        address[] memory topArbitrators = getTopArbitrators();
        employerArbitrators = topArbitrators;

        lastElectionTime = block.timestamp;
    }

    function getTopArbitrators() internal view returns (address[] memory) {
        uint256 maxArbitrators = 5;
        address[] memory topArbitrators = new address[](maxArbitrators);
        uint256[] memory topVotes = new uint256[](maxArbitrators);

        for (uint256 i = 0; i < daoMembers.length; i++) {
            address arbitrator = daoMembers[i];
            uint256 votes = arbitratorData[arbitrator].votes;

            for (uint256 j = 0; j < maxArbitrators; j++) {
                if (votes > topVotes[j]) {
                    for (uint256 k = maxArbitrators - 1; k > j; k--) {
                        topVotes[k] = topVotes[k - 1];
                        topArbitrators[k] = topArbitrators[k - 1];
                    }
                    topVotes[j] = votes;
                    topArbitrators[j] = arbitrator;
                    break;
                }
            }
        }

        return topArbitrators;
    }

    function getEmployerArbitrators() public view override returns (address[] memory) {
        return employerArbitrators;
    }
}
