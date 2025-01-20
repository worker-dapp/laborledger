// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title WorkerDAO
 * @dev A decentralized autonomous organization (DAO) for workers with tiered membership
 * and welfare fund management.
 *
 * STRUCTURE:
 * 1. Membership Tiers:
 *    - BASIC: New members, limited benefits
 *    - ACTIVE: Regular participants, increased voting power
 *    - CORE: Highly active members, higher fund request limits
 *    - ELDER: Long-term engaged members, auto-approval privileges
 *
 * 2. Welfare Fund:
 *    - Members contribute ETH to shared fund
 *    - Request-based distribution system
 *    - Tiered maximum request amounts
 *    - Auto-approval for trusted members
 *
 * 3. Governance:
 *    - Democratic voting on fund requests
 *    - Arbitrator election system
 *    - Voting power weighted by tier
 *
 * 4. Activity Tracking:
 *    - Contribution history
 *    - Voting participation
 *    - Request history
 *    - Time-based activity monitoring
 *
 * MAIN FEATURES:
 * - Progressive Benefits: Higher tiers get increased voting power and request limits
 * - Activity Requirements: Tiers based on contribution and participation
 * - Automatic Downgrades: Inactivity leads to tier reduction
 * - Democratic Control: Major decisions require member voting
 * - Arbitration System: Elected arbitrators handle disputes
 * - Auto-Approval: Trusted members get expedited request processing
 * 
 * TIER REQUIREMENTS:
 * - BASIC: Initial membership
 * - ACTIVE: 10+ votes cast
 * - CORE: 1 ETH contributed, 30+ votes
 * - ELDER: 2 ETH contributed, 50+ votes, 5+ successful requests
 *
 * @notice This contract manages worker welfare, governance, and participation incentives
 * @dev All monetary values are in Wei
 */

import "../interfaces/IWorkerDAO.sol";

contract WorkerDAO is IWorkerDAO {
    struct Arbitrator {
        address arbitratorAddress;
        uint256 votes;
        uint256 casesHandled;
        uint256 casesOverturned;
    }

    struct FundRequest {
        address worker;
        uint256 amount;
        string reason;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool resolved;
    }

    struct MemberStatus {
        uint256 totalContributions;    // Total ETH contributed
        uint256 activeRequests;        // Number of active fund requests
        uint256 successfulRequests;    // Number of approved requests
        uint256 votingParticipation;   // Number of votes cast
        uint256 lastActivityTime;      // Last interaction timestamp
        MemberTier tier;               // Current member tier
    }

    enum MemberTier {
        BASIC,      // New members
        ACTIVE,     // Regular participants
        CORE,       // Highly active members
        ELDER       // Long-term, highly engaged members
    }

    address[] public workerArbitrators;
    address[] public daoMembers;
    mapping(address => bool) public isDAOMember;
    mapping(address => uint256) public memberContributions;
    mapping(address => Arbitrator) public arbitratorData;
    mapping(address => bool) public hasVotedForArbitrator;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnRequest;
    mapping(address => MemberStatus) public memberStatus;
    mapping(MemberTier => uint256) public tierVotingPower;
    mapping(MemberTier => uint256) public tierRequestLimit;
    mapping(MemberTier => uint256) public tierMaxRequest;

    uint256 public welfareFund;
    uint256 public lastElectionTime;
    uint256 public electionInterval = 180 days; // Elections every 6 months
    uint256 public autoApprovalThreshold = 1 ether; // Small requests auto-approved
    uint256 public constant ACTIVITY_TIMEOUT = 180 days;
    uint256 public constant MIN_CORE_CONTRIBUTION = 1 ether;
    uint256 public constant MIN_ELDER_CONTRIBUTION = 2 ether;

    FundRequest[] public fundRequests;

    event WorkerJoinedDAO(address worker);
    event ContributionMade(address worker, uint256 amount);
    event ArbitratorNominated(address arbitrator);
    event ArbitratorElected(address arbitrator);
    event WelfareFundUpdated(uint256 newBalance);
    event FundRequestSubmitted(uint256 requestId, address worker, uint256 amount, string reason);
    event FundRequestVoted(uint256 requestId, address voter, bool vote);
    event FundRequestResolved(uint256 requestId, bool approved, uint256 amountDisbursed);
    event MemberTierUpdated(address indexed member, MemberTier newTier);
    event ActivityRecorded(address indexed member, string activityType);

    modifier onlyDAOMember() {
        require(isDAOMember[msg.sender], "Only DAO members can vote");
        _;
    }

    constructor() {
        lastElectionTime = block.timestamp;
        tierVotingPower[MemberTier.BASIC] = 1;
        tierVotingPower[MemberTier.ACTIVE] = 2;
        tierVotingPower[MemberTier.CORE] = 3;
        tierVotingPower[MemberTier.ELDER] = 4;

        tierRequestLimit[MemberTier.BASIC] = 1;
        tierRequestLimit[MemberTier.ACTIVE] = 2;
        tierRequestLimit[MemberTier.CORE] = 3;
        tierRequestLimit[MemberTier.ELDER] = 4;

        tierMaxRequest[MemberTier.BASIC] = 0.5 ether;
        tierMaxRequest[MemberTier.ACTIVE] = 1 ether;
        tierMaxRequest[MemberTier.CORE] = 2 ether;
        tierMaxRequest[MemberTier.ELDER] = 3 ether;
    }

    function joinDAO() public override {
        require(!isDAOMember[msg.sender], "Already a member");
        isDAOMember[msg.sender] = true;
        daoMembers.push(msg.sender);
        
        memberStatus[msg.sender] = MemberStatus({
            totalContributions: 0,
            activeRequests: 0,
            successfulRequests: 0,
            votingParticipation: 0,
            lastActivityTime: block.timestamp,
            tier: MemberTier.BASIC
        });

        emit WorkerJoinedDAO(msg.sender);
    }

    function contributeToFund() public payable override onlyDAOMember {
        require(msg.value > 0, "Contribution must be greater than zero");
        welfareFund += msg.value;
        memberContributions[msg.sender] += msg.value;
        
        memberStatus[msg.sender].totalContributions += msg.value;
        memberStatus[msg.sender].lastActivityTime = block.timestamp;
        updateMemberTier(msg.sender);

        emit ContributionMade(msg.sender, msg.value);
        emit WelfareFundUpdated(welfareFund);
    }

    function requestFunds(uint256 amount, string memory reason) public override onlyDAOMember {
        MemberStatus storage status = memberStatus[msg.sender];
        require(amount <= welfareFund, "Insufficient funds in the welfare pool");
        require(amount <= tierMaxRequest[status.tier], "Amount exceeds tier limit");
        require(status.activeRequests < tierRequestLimit[status.tier], "Request limit reached");

        if (status.tier == MemberTier.ELDER && amount <= autoApprovalThreshold) {
            welfareFund -= amount;
            payable(msg.sender).transfer(amount);
            status.successfulRequests++;
            emit FundRequestResolved(fundRequests.length, true, amount);
            emit WelfareFundUpdated(welfareFund);
            return;
        }

        status.activeRequests++;

        fundRequests.push(FundRequest({
            worker: msg.sender,
            amount: amount,
            reason: reason,
            yesVotes: 0,
            noVotes: 0,
            endTime: block.timestamp + 7 days,
            resolved: false
        }));

        emit FundRequestSubmitted(fundRequests.length - 1, msg.sender, amount, reason);
    }

    function voteOnRequest(uint256 requestId, bool voteYes) public onlyDAOMember {
        require(requestId < fundRequests.length, "Invalid request ID");
        require(!hasVotedOnRequest[requestId][msg.sender], "You have already voted");
        require(block.timestamp <= fundRequests[requestId].endTime, "Voting period has ended");

        if (voteYes) {
            fundRequests[requestId].yesVotes++;
        } else {
            fundRequests[requestId].noVotes++;
        }

        hasVotedOnRequest[requestId][msg.sender] = true;

        emit FundRequestVoted(requestId, msg.sender, voteYes);
    }

    function resolveFundRequest(uint256 requestId) public {
        require(requestId < fundRequests.length, "Invalid request ID");
        FundRequest storage request = fundRequests[requestId];
        require(block.timestamp > request.endTime, "Voting period not yet ended");
        require(!request.resolved, "Request already resolved");

        bool approved = request.yesVotes > request.noVotes;

        if (approved) {
            payable(request.worker).transfer(request.amount);
            welfareFund -= request.amount;
        }

        request.resolved = true;

        emit FundRequestResolved(requestId, approved, approved ? request.amount : 0);
        emit WelfareFundUpdated(welfareFund);
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
        workerArbitrators = topArbitrators;

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

    function getWorkerArbitrators() public view override returns (address[] memory) {
        return workerArbitrators;
    }

    function getFundRequests() public view returns (FundRequest[] memory) {
        return fundRequests;
    }

    function updateMemberTier(address member) internal {
        MemberStatus storage status = memberStatus[member];
        MemberTier newTier = calculateTier(member);
        
        if (newTier != status.tier) {
            status.tier = newTier;
            emit MemberTierUpdated(member, newTier);
        }
    }

    function calculateTier(address member) internal view returns (MemberTier) {
        MemberStatus memory status = memberStatus[member];
        
        if (block.timestamp - status.lastActivityTime > ACTIVITY_TIMEOUT) {
            return MemberTier.BASIC;
        }

        if (status.totalContributions >= MIN_ELDER_CONTRIBUTION &&
            status.votingParticipation >= 50 &&
            status.successfulRequests >= 5) {
            return MemberTier.ELDER;
        }

        if (status.totalContributions >= MIN_CORE_CONTRIBUTION &&
            status.votingParticipation >= 30) {
            return MemberTier.CORE;
        }

        if (status.votingParticipation >= 10) {
            return MemberTier.ACTIVE;
        }

        return MemberTier.BASIC;
    }

    function getMemberTier(address member) external view returns (MemberTier) {
        return memberStatus[member].tier;
    }

    function getMemberVotingPower(address member) public view returns (uint256) {
        return tierVotingPower[memberStatus[member].tier];
    }
}
