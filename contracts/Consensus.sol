// SPDX-License-Identifier: GPL-3.0
/// @notice Contract managing consensus members and proposals
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IWBlockToken} from "./interfaces/IWBlockToken.sol";
import {IGovernanceContract} from "./interfaces/IGovernanceContract.sol";
import {ILiquidityManagedToken} from "./interfaces/ILiquidityManagedToken.sol";
import {IConsensusErrors} from "./utils/IConsensusErrors.sol";

/**
 * @title WinnerBlock Consensus Contract
 * @dev This contract is part of the WinnerBlock decentralized gaming ecosystem, licensed under the GNU General Public License v3.0 (GPL-3.0) to ensure it remains open source. It interacts with other contracts within the WinnerBlock system to manage ecosystem mechanics, token settings, player assets, and more.
 *
 * The WinnerBlock ecosystem aims to be fully open and collaborative, allowing developers and gamers to contribute to its growth. By adopting the GPL-3.0 license, we commit to sharing all enhancements to the ecosystem, fostering innovation and fairness.
 *
 * Learn more about WinnerBlock:
 * - Website: https://WinnerBlock.io
 * - Telegram: https://t.me/WinnerBlock
 *
 * These links provide access to our community and the latest information about the WinnerBlock ecosystem. Join us in building a transparent and fair gaming world!
 *
 */
/// @custom:security-contact security@winnerblock.io
contract ConsensusContract is
    Initializable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    IConsensusErrors
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Authorize upgrade function for UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Storage gap for upgradeable contract
    uint256[50] private __gap;

    /// @notice Role identifier for members of the consensus system
    /// @dev This role is used to define access control for consensus-related operations
    bytes32 public constant CONSENSUS_MEMBER_ROLE =
        keccak256("CONSENSUS_MEMBER_ROLE");

    /// @notice Governance Contract address
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice List of addresses that are members of the consensus system
    address[] public consensusMembers;

    /// @notice Total number of consensus members in the system
    uint256 public consensusMemberCount;

    /// @notice Ecosystem Token contract address
    IWBlockToken public tokenContract;

    /// @notice Address of the permanent founder seat in consensus
    address public founder;

    /// @notice Liquidity management contract
    ILiquidityManagedToken public liquidityContract;

    struct GovernanceProposal {
        uint256 proposalType;
        bytes data;
        uint256 voteCountForApproval;
        uint256 voteCountAgainst;
        mapping(address reviewer => bool hasReviewed) reviewedBy;
        mapping(address approver => bool hasApproved) approvedBy;
        mapping(address voter => bool hasVoted) voted;
        bool reviewed;
        bool approved;
        uint256 voteCountForReview;
    }

    struct Proposal {
        bytes data;
        bool executed;
        uint256 voteCount;
        mapping(address voter => bool hasVoted) voted;
    }

    /// @notice Stores details of proposals by their unique IDs
    mapping(uint256 proposalId => Proposal proposalDetails) public proposals;

    /// @notice The total count of proposals in the system
    uint256 public proposalCount;

    /// @notice Stores details of governance proposals by their unique IDs
    mapping(uint256 proposalId => GovernanceProposal proposalDetails)
        public governanceProposals;

    /// @notice The total count of governance proposals in the system
    uint256 public governanceProposalCount;

    /// @notice The address of the governance contract
    address public governanceContractAddress;

    /// @notice The number of proposals after which a purge will be triggered
    uint256 public PURGE_TRIGGER_COUNT;

    /// @notice The number of most recent proposals to retain during a purge
    uint256 public PROPOSALS_TO_KEEP;

    /// @notice State variable for next purge in proposal counts
    uint256 public nextPurgeThreshold;

    /// @notice Tracks the proposals on which a specific member has voted
    /// @dev Each member address is mapped to an array of `proposalIds` they have voted on
    mapping(address member => uint[] proposalIds) private memberVotedProposals;

    /// @notice Event declarations
    event Initialized(address indexed tokenAddress, address indexed founder);

    /// @notice Initializes the contract and sets the necessary parameters
    /// @dev This function sets up access control roles, initializes key variables, and assigns the founder to deployer.
    /// @param _tokenAddress The address of the token contract used in the system
    function initialize(address _tokenAddress) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONSENSUS_MEMBER_ROLE, msg.sender);
        tokenContract = IWBlockToken(_tokenAddress);
        consensusMemberCount = 1;
        PURGE_TRIGGER_COUNT = 50;
        PROPOSALS_TO_KEEP = 10;
        founder = msg.sender;

        nextPurgeThreshold = PURGE_TRIGGER_COUNT; // Initialize here

        emit Initialized(_tokenAddress, msg.sender);
    }

    /// @notice Event declarations
    event GovernanceContractSet(address indexed newAddress);

    /// @notice Set the address of the governance contract
    /// @param _governanceContractAddress Address of the governance contract
    function setGovernanceContract(
        address _governanceContractAddress
    ) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerIsNotAdmin();
        }
        governanceContractAddress = _governanceContractAddress;
        _grantRole(GOVERNANCE_ROLE, _governanceContractAddress);

        emit GovernanceContractSet(_governanceContractAddress);
    }

    // Constants for proposal types (all are not used here)
    uint256 internal constant TYPE_GAME_WHITELIST_PROPOSAL = 1;
    uint256 internal constant TYPE_CONSENSUS_MEMBER_PROPOSAL = 2;
    uint256 internal constant TYPE_EMERGENCY_RESET_PROPOSAL = 3;
    uint256 internal constant TYPE_SETTING_UPDATE_PROPOSAL = 4;
    uint256 internal constant TYPE_CONTRACT_UPGRADE_PROPOSAL = 5;

    function recordVote(address member, uint256 proposalId) private {
        memberVotedProposals[member].push(proposalId);
    }

    /// @notice Event declarations
    event PurgeMemberStart(address indexed member, uint256 proposalsLength);

    /// @notice Event declarations
    event MemberVotingDataPurged(address indexed member, uint256 proposalsKept);

    /// @notice Purge old member voting data
    /// @param _keepCount Number of recent proposals to keep in member voting data
    function purgeOldMemberVotingData(uint256 _keepCount) private {
        uint256 consensusMembersLength = consensusMembers.length;

        for (uint256 i; i < consensusMembersLength; ++i) {
            address member = consensusMembers[i];
            uint[] storage votedProposals = memberVotedProposals[member];

            emit PurgeMemberStart(member, votedProposals.length); // Debug log

            if (votedProposals.length > _keepCount) {
                uint256 deleteCount = votedProposals.length - _keepCount;
                for (uint256 j; j < deleteCount; ++j) {
                    removeOldestEntry(member);
                }
                emit MemberVotingDataPurged(member, _keepCount);
            } else {
                // Log when no purging is needed
                emit MemberVotingDataPurged(member, votedProposals.length);
            }
        }
    }

    /// @notice Event declarations
    event OldestEntryRemoved(address indexed member);

    /// @notice Remove the oldest entry from member voting data
    /// @param member Address of the member whose voting data is being purged
    function removeOldestEntry(address member) private {
        uint256 length = memberVotedProposals[member].length;

        if (memberVotedProposals[member].length == 0) {
            revert NoEntriesToRemove();
        }
        for (uint256 i; i < length - 1; ++i) {
            memberVotedProposals[member][i] = memberVotedProposals[member][
                i + 1
            ];
        }
        memberVotedProposals[member].pop();

        emit OldestEntryRemoved(member);
    }

    /// @notice Event declarations
    event DataPurgeStart(
        uint256 governanceProposalCount,
        uint256 indexed nextPurgeThreshold
    );

    /// @notice Event declarations
    event GovernanceProposalCreated(
        uint256 indexed proposalId,
        uint256 proposalType,
        bytes data,
        bool autoApproved
    );

    /// @notice Create a new governance proposal
    /// @param proposalType Type of the proposal
    /// @param data Data associated with the proposal
    /// @return autoApproved Whether the proposal was auto-approved
    function createGovernanceProposal(
        uint256 proposalType,
        bytes memory data
    ) external nonReentrant returns (bool autoApproved) {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerIsNotGovernance();
        }

        // Increment governanceProposalCount explicitly before using it
        governanceProposalCount++;

        GovernanceProposal storage proposal = governanceProposals[
            governanceProposalCount - 1
        ];
        proposal.proposalType = proposalType;
        proposal.data = data;

        // Default to not auto-approved
        proposal.reviewed = false;
        proposal.approved = false;
        autoApproved = false;

        // Check conditions for auto-approval
        if (
            proposalType == TYPE_SETTING_UPDATE_PROPOSAL ||
            proposalType == TYPE_EMERGENCY_RESET_PROPOSAL
        ) {
            // Setting update and emergency reset proposals are always auto-approved
            proposal.reviewed = true;
            proposal.approved = true;
            autoApproved = true;
        } else if (proposalType == TYPE_CONTRACT_UPGRADE_PROPOSAL) {
            // Contract upgrade proposals must be reviewed manually
            proposal.reviewed = false;
            proposal.approved = false;
            autoApproved = false;
        } else if (proposalType == TYPE_CONSENSUS_MEMBER_PROPOSAL) {
            (, bool isAdding) = abi.decode(data, (address, bool));
            if (isAdding && consensusMemberCount == 1) {
                // Consensus member adding proposals are auto-approved if there is only one member
                proposal.reviewed = true;
                proposal.approved = true;
                autoApproved = true;
            } else if (!isAdding) {
                // Consensus member removing proposals are auto-approved regardless of member count
                proposal.reviewed = true;
                proposal.approved = true;
                autoApproved = true;
            }
        }

        // Triggering purge when a certain number of proposals have been created
        if (governanceProposalCount >= nextPurgeThreshold) {
            // Log the current state even if condition is not met
            emit DataPurgeStart(governanceProposalCount, nextPurgeThreshold);

            // Trigger purge
            purgeOldMemberVotingData(PROPOSALS_TO_KEEP);

            // Update the next threshold
            nextPurgeThreshold += PURGE_TRIGGER_COUNT;
        }

        emit GovernanceProposalCreated(
            governanceProposalCount - 1,
            proposalType,
            data,
            autoApproved
        );

        return autoApproved;
    }

    /// @notice Event declarations
    event GovernanceProposalReviewed(
        uint256 indexed proposalId,
        address indexed reviewer,
        uint256 voteCountForReview
    );

    /// @notice Allow consensus members to review a governance proposal
    /// @param _proposalId ID of the governance proposal to review
    function reviewGovernanceProposal(
        uint256 _proposalId
    ) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        GovernanceProposal storage proposal = governanceProposals[_proposalId];

        // Prevent reviewing if the proposal is already reviewed and approved
        if (proposal.reviewed) {
            revert ProposalAlreadyReviewed();
        }

        proposal.reviewedBy[msg.sender] = true;
        proposal.voteCountForReview++;
        recordVote(msg.sender, _proposalId);

        if (proposal.voteCountForReview >= (consensusMemberCount + 1) / 2) {
            proposal.reviewed = true;
        }

        emit GovernanceProposalReviewed(
            _proposalId,
            msg.sender,
            proposal.voteCountForReview
        );
    }

    /// @notice Event declarations
    event GovernanceProposalApproved(
        uint256 indexed proposalId,
        address indexed approver,
        bool approved
    );

    /// @notice Allow consensus members to approve or reject a governance proposal
    /// @param _proposalId ID of the governance proposal to approve or reject
    /// @param _approve Whether to approve or reject the proposal
    function approveGovernanceProposal(
        uint256 _proposalId,
        bool _approve
    ) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        GovernanceProposal storage proposal = governanceProposals[_proposalId];

        // Ensure the proposal has been reviewed before it can be approved
        if (!proposal.reviewed) {
            revert ProposalNotReviewed();
        }

        // Prevent approving if the proposal is already finalized
        if (proposal.approved) {
            revert ProposalAlreadyFinalized();
        }

        proposal.approvedBy[msg.sender] = true;

        if (_approve) {
            proposal.voteCountForApproval++;
        } else {
            proposal.voteCountAgainst++;
        }

        // Determine if the proposal is approved based on consensus rules
        uint256 requiredVotes = (consensusMemberCount == 1)
            ? 1
            : (consensusMemberCount * 2) / 3;

        if (proposal.voteCountForApproval >= requiredVotes) {
            proposal.approved = true;
        } else if (proposal.voteCountAgainst >= requiredVotes) {
            proposal.approved = false;
        }

        // Optionally update proposal status in the GovernanceContract, if integrated
        if (governanceContractAddress != address(0)) {
            IGovernanceContract(governanceContractAddress).updateProposalStatus(
                    _proposalId,
                    proposal.reviewed,
                    proposal.approved
                );
        }

        emit GovernanceProposalApproved(
            _proposalId,
            msg.sender,
            proposal.approved
        );
    }

    /// @notice Get the review status of a governance proposal
    /// @param _proposalId ID of the governance proposal
    /// @return reviewed Whether the proposal has been reviewed
    /// @return approved Whether the proposal has been approved
    function getGovernanceProposalReview(
        uint256 _proposalId
    ) external view returns (bool reviewed, bool approved) {
        // Named return variables are directly set
        reviewed = governanceProposals[_proposalId].reviewed;
        approved = governanceProposals[_proposalId].approved;
    }

    /// @notice Finalize a governance proposal
    /// @param _proposalId ID of the proposal to finalize
    function finalizeGovernanceProposal(
        uint256 _proposalId
    ) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        IGovernanceContract governanceContract = IGovernanceContract(
            governanceContractAddress
        );
        governanceContract.finalizeProposal(_proposalId);
    }

    /// @notice Execute a governance proposal
    /// @param _proposalId ID of the proposal to execute
    function executeGovernanceProposal(
        uint256 _proposalId
    ) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }

        // Retrieve the proposal details
        GovernanceProposal storage proposal = governanceProposals[_proposalId];

        // Ensure the proposal has been reviewed and approved
        if (!proposal.reviewed) {
            revert ProposalNotReviewed();
        }
        if (!proposal.approved) {
            revert ProposalNotApproved();
        }

        // Execute the proposal in the Governance contract
        IGovernanceContract governanceContract = IGovernanceContract(
            governanceContractAddress
        );
        governanceContract.executeProposal(_proposalId);
    }

    /// @notice Event declarations
    event ProposalCreated(uint256 indexed proposalId, bytes data);

    /// @notice Create a new proposal
    /// @param _data Data associated with the proposal
    function createProposal(bytes memory _data) private {
        Proposal storage proposal = proposals[proposalCount++];
        proposal.data = _data;
        proposal.executed = false;
        proposal.voteCount = 0;

        emit ProposalCreated(proposalCount - 1, _data);
    }

    /// @notice Check and remove inactive consensus members
    function checkAndRemoveInactiveMembers() private {
        if (proposalCount < 5) return; // Not enough proposals to check

        uint256 latestProposalId = proposalCount - 1;
        uint256 secondLatestProposalId = proposalCount - 5;

        // Iterate in reverse to avoid array shifting issues
        for (uint256 i = consensusMembers.length; i > 0; i--) {
            address member = consensusMembers[i - 1];

            // Skip the founder
            if (member == founder) continue;

            // Check if the member has voted on the last two proposals
            if (
                !hasVotedOnLastFiveProposals(
                    member,
                    latestProposalId,
                    secondLatestProposalId
                )
            ) {
                revokeConsensusMemberRoleInternal(member);
            }
        }
    }

    function hasVotedOnLastFiveProposals(
        address member,
        uint256 latestProposalId,
        uint256 secondLatestProposalId
    ) private view returns (bool hasVoted) {
        uint[] memory votedProposals = memberVotedProposals[member];
        uint256 votedCount = votedProposals.length;

        hasVoted =
            votedCount >= 5 &&
            votedProposals[votedCount - 1] == latestProposalId &&
            votedProposals[votedCount - 5] == secondLatestProposalId;
        return hasVoted;
    }

    /// @notice Allow consensus members to vote on a proposal
    /// @param _proposalId ID of the proposal to vote on
    function voteProposal(uint256 _proposalId) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.voted[msg.sender]) {
            revert AlreadyVoted();
        }
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Finalize state updates before calling external functions
        proposal.voted[msg.sender] = true;
        proposal.voteCount++;
        recordVote(msg.sender, _proposalId);

        if (proposal.voteCount >= (consensusMemberCount * 2) / 3) {
            checkAndRemoveInactiveMembers();

            // Set executed state before external call to avoid inconsistencies
            proposal.executed = true;
            emit ProposalExecuted(_proposalId);

            // Call executeProposal (external call occurs here)
            executeProposal(_proposalId);
        }
    }

    /// @notice Event declarations
    event ProposalExecuted(uint256 indexed proposalId);

    /// @notice Execute a proposal
    /// @param _proposalId ID of the proposal to execute
    function executeProposal(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];

        // Perform the external call
        (bool success, ) = address(tokenContract).call(proposal.data);
        if (!success) {
            revert ExecutionFailed();
        }
    }

    /// @notice Event declarations
    event ConsensusMemberGranted(address indexed newMember);

    /// @notice Grant consensus member role to a new address
    /// @param _newMember Address of the new consensus member
    function grantConsensusMemberRole(address _newMember) external {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerIsNotGovernance();
        }
        if (_newMember == founder) {
            revert InvalidOperationOnFounder();
        }
        _grantRole(CONSENSUS_MEMBER_ROLE, _newMember);
        consensusMembers.push(_newMember);
        consensusMemberCount++;

        emit ConsensusMemberGranted(_newMember);
    }

    /// @notice Trigger to revoke consensus member role from an address
    /// @param _member Address of the consensus member to revoke
    function revokeConsensusMemberRole(address _member) external {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerIsNotGovernance();
        }
        revokeConsensusMemberRoleInternal(_member);
    }

    /// @notice Event declarations
    event ConsensusMemberRevoked(address indexed member);

    /// @notice Revoke consensus member role from an address
    /// @param _member Address of the consensus member to revoke
    function revokeConsensusMemberRoleInternal(address _member) private {
        if (_member == founder) {
            revert InvalidOperationOnFounder();
        }
        _revokeRole(CONSENSUS_MEMBER_ROLE, _member);
        removeMemberFromArray(_member);
        consensusMemberCount -= 1;

        emit ConsensusMemberRevoked(_member);
    }

    /// @notice Revoke consensus member role from all members
    function revokeAllConsensusMembers() external {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerIsNotGovernance();
        }
        uint256 consensusMembersLength = consensusMembers.length;
        for (uint256 i; i < consensusMembersLength; ++i) {
            if (consensusMembers[i] != founder) {
                _revokeRole(CONSENSUS_MEMBER_ROLE, consensusMembers[i]);
            }
        }
        delete consensusMembers;
        consensusMembers.push(founder); // Ensure founder is retained
        consensusMemberCount = 1; // Reset count to include only the founder
    }

    /// @notice Remove a member from the consensus members array
    /// @param _member Address of the member to remove
    function removeMemberFromArray(address _member) private {
        if (_member == founder) {
            revert InvalidOperationOnFounder();
        }
        uint256 consensusMembersLength = consensusMembers.length;
        for (uint256 i; i < consensusMembersLength; ++i) {
            if (consensusMembers[i] == _member) {
                consensusMembers[i] = consensusMembers[
                    consensusMembersLength - 1
                ];
                consensusMembers.pop();
                return; // Exit after removing the member
            }
        }
    }

    /// @notice Get all consensus members
    /// @return members Array of consensus member addresses
    function getAllConsensusMembers()
        external
        view
        returns (address[] memory members)
    {
        members = consensusMembers;
    }

    /// @notice Check if an address is a consensus member
    /// @param _member Address to check
    /// @return isMember Whether the address is a consensus member or not
    function isConsensusMember(
        address _member
    ) external view returns (bool isMember) {
        isMember = hasRole(CONSENSUS_MEMBER_ROLE, _member);
    }

    /// @notice Create a proposal to pause the token contract
    function createPauseProposal() external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        bytes memory data = abi.encodeCall(tokenContract.pause, ()); // Correct usage
        createProposal(data);
    }

    /// @notice Create a proposal to unpause the token contract
    function createUnpauseProposal() external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        bytes memory data = abi.encodeCall(tokenContract.unpause, ()); // Correct usage
        createProposal(data);
    }

    /// @notice Create a proposal to remove a game from the whitelist
    /// @param _gameContractAddress Address of the game contract to be removed
    function createGameRemoveProposal(
        address _gameContractAddress
    ) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }

        // Check if the game is currently active before allowing removal proposal
        if (!tokenContract.isGameActive(_gameContractAddress)) {
            revert GameNotActiveOrNotWhitelisted();
        }

        // Encode the function call
        bytes memory data = abi.encodeCall(
            tokenContract.removeFromGameWhitelist,
            (_gameContractAddress)
        );

        // Create the proposal
        createProposal(data);
    }

    /// @notice Event declarations
    event LiquidityContractSet(address indexed newAddress);

    /// @notice Set the liquidity contract address
    /// @param _liquidityContract Address of the liquidity contract
    function setLiquidityContract(
        address _liquidityContract
    ) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerIsNotAdmin();
        }
        liquidityContract = ILiquidityManagedToken(_liquidityContract);

        emit LiquidityContractSet(_liquidityContract);
    }

    /// @notice Add initial liquidity for the token
    function addInitialLiquidity() external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }

        // Call the liquidityContract's addInitialLiquidity function directly
        liquidityContract.initialLiquidity();
    }

    /// @notice Execute burning of rewards for a proposal
    /// @param _proposalId ID of the proposal for which rewards are to be burned
    function executeBurnRewards(uint256 _proposalId) external nonReentrant {
        if (!hasRole(CONSENSUS_MEMBER_ROLE, msg.sender)) {
            revert CallerIsNotConsensusMember();
        }
        IGovernanceContract governanceContract = IGovernanceContract(
            governanceContractAddress
        );
        governanceContract.burnRewards(_proposalId);
    }
}
