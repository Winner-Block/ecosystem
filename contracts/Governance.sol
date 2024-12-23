// SPDX-License-Identifier: GPL-3.0
/// @notice Contract allowing holders governance
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IConsensusContract} from "./interfaces/IConsensusContract.sol";
import {IWBlockToken} from "./interfaces/IWBlockToken.sol";
import {IRewardContract} from "./interfaces/IRewardContract.sol";
import {GovernanceSetting} from "./utils/GovernanceTypes.sol";
import {IGovernanceErrors} from "./utils/IGovernanceErrors.sol";

/**
 * @title WinnerBlock Governance Contract
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
contract GovernanceContract is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IGovernanceErrors
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /// @notice Storage gap for upgradeable contract
    uint256[50] private __gap;

    /// @notice Ecosystem Token Contract address
    IERC20 public token;

    /// @notice Consensus Contract address
    IConsensusContract public consensusContract;

    /// @notice Reward Contract address
    IRewardContract public rewardContract;

    struct Proposal {
        address proposer;
        uint256 proposalType;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address voter => bool hasVoted) voted;
        bool executed;
        bool result;
        bool reviewed;
        bool approved;
        bool autoApproved;
        uint256 createdAtBlock;
    }

    /// @notice Mapping to store the details of proposals by their unique IDs
    mapping(uint256 proposalId => Proposal proposalDetails) public proposals;

    /// @notice The total number of proposals created
    uint256 public proposalCount;

    /// @notice Tracks the amount of tokens staked by each staker for a specific proposal
    /// @dev The first key is the `proposalId`, and the second key is the staker's address
    /// @return stakedAmount The amount of tokens staked by the staker for the proposal
    mapping(uint256 proposalId => mapping(address staker => uint256 stakedAmount))
        public stakedTokens;

    /// @notice Tracks the total amount of tokens staked at the time of proposal execution
    /// @return totalStaked The total amount of tokens staked for the proposal at execution
    mapping(uint256 proposalId => uint256 totalStaked)
        public totalStakedAtExecution;

    /// @notice Tracks the total rewards allocated at the time of proposal execution
    /// @return totalRewards The total rewards allocated for the proposal at execution
    mapping(uint256 proposalId => uint256 totalRewards)
        public totalRewardsAtExecution;

    /// @notice Tracks the total distributed rewards for each proposal
    /// @return distributedRewards The total rewards distributed for the proposal
    mapping(uint256 proposalId => uint256 distributedRewards)
        public totalDistributedRewards;

    /// @notice Tracks the total tokens staked across all participants for a specific proposal
    /// @return totalTokensStaked The total tokens staked for the proposal
    mapping(uint256 proposalId => uint256 totalTokensStaked)
        public totalStakedTokens;

    /// @notice The address of the token contract used for staking and rewards
    /// @dev This address is used to interact with the token contract
    address public tokenContractAddress;

    /// @notice Constants for proposal types
    uint256 internal constant TYPE_GAME_WHITELIST_PROPOSAL = 1;
    uint256 internal constant TYPE_CONSENSUS_MEMBER_PROPOSAL = 2;
    uint256 internal constant TYPE_EMERGENCY_RESET_PROPOSAL = 3;
    uint256 internal constant TYPE_SETTING_UPDATE_PROPOSAL = 4;
    uint256 internal constant TYPE_CONTRACT_UPGRADE_PROPOSAL = 5;

    /// @notice Event emitted when the contract is initialized
    event Initialized(
        address indexed tokenAddress,
        address indexed consensusContract,
        address indexed owner
    );

    /// @notice Initializes the contract and sets up the necessary configurations
    /// @dev This function sets up the token, consensus contract, and ownership
    /// It initializes the inherited contracts and assigns critical addresses
    /// @param _tokenAddress The address of the ERC20 token contract used for staking and rewards
    /// @param _consensusContractAddress The address of the consensus contract used for governance and voting
    /// @param _owner The address of the contract owner
    function initialize(
        address _tokenAddress,
        address _consensusContractAddress,
        address _owner
    ) external initializer {
        __Ownable_init(_owner); // Pass the owner address
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        token = IERC20(_tokenAddress);
        consensusContract = IConsensusContract(_consensusContractAddress);
        tokenContractAddress = _tokenAddress;

        emit Initialized(_tokenAddress, _consensusContractAddress, _owner);
    }

    /// @notice Event emitted when a reward contract is set
    event RewardContractSet(address indexed rewardContractAddress);

    /// @notice Sets the address of the reward contract
    /// @param _rewardContractAddress Address of the reward contract
    function setRewardContract(
        address _rewardContractAddress
    ) external onlyOwner {
        rewardContract = IRewardContract(_rewardContractAddress);
        emit RewardContractSet(_rewardContractAddress);
    }

    function getTokenContract() private view returns (IWBlockToken) {
        return IWBlockToken(tokenContractAddress);
    }

    /// @notice Event emitted when a proposal's status is updated
    event ProposalStatusUpdated(
        uint256 indexed proposalId,
        bool reviewed,
        bool approved
    );

    /// @notice Updates the status of a proposal
    /// @param _proposalId ID of the proposal
    /// @param _reviewed Whether the proposal has been reviewed
    /// @param _approved Whether the proposal has been approved
    function updateProposalStatus(
        uint256 _proposalId,
        bool _reviewed,
        bool _approved
    ) external {
        if (msg.sender != address(consensusContract)) {
            revert CallerNotConsensusContract();
        }

        Proposal storage proposal = proposals[_proposalId];
        proposal.reviewed = _reviewed;
        proposal.approved = _approved;

        emit ProposalStatusUpdated(_proposalId, _reviewed, _approved);
    }

    /// @notice Event emitted when a new proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 proposalType,
        bytes data,
        bool autoApproved
    );

    /// @notice Creates a new governance proposal
    /// @param proposalType Type of the proposal
    /// @param data Additional data for the proposal
    function createProposal(uint256 proposalType, bytes memory data) private {
        // Retrieve the IWBlockToken contract and get the total supply
        IWBlockToken tokenContract = getTokenContract();
        uint256 totalSupply = tokenContract.totalSupply();

        // Retrieve the proposal cost in basis points
        uint256 proposalCostBasisPoints = tokenContract.getSettingValue(
            GovernanceSetting.ProposalCost
        );

        // Convert basis points to proposal cost as a percentage of total supply
        // Note: 1 basis point = 0.01% or 0.0001 in fraction
        uint256 proposalCost = (totalSupply * proposalCostBasisPoints) / 10000;

        // Check if the sender has enough tokens for the proposal cost
        if (token.balanceOf(msg.sender) < proposalCost) {
            revert InsufficientTokensForStake();
        }

        // Check validity of setting update proposal before creating it
        if (proposalType == TYPE_SETTING_UPDATE_PROPOSAL) {
            (GovernanceSetting setting, uint256 proposedValue) = abi.decode(
                data,
                (GovernanceSetting, uint256)
            );
            if (!isValidSettingValue(setting, proposedValue)) {
                revert InvalidSettingValue();
            }
        }

        uint256 currentProposalId = proposalCount; // Capture current ID

        // Initialize the new proposal
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.proposer = msg.sender;
        newProposal.proposalType = proposalType;
        newProposal.data = data;
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;
        newProposal.executed = false;
        newProposal.result = false;
        newProposal.createdAtBlock = block.number;

        // Increment proposal count for the next proposal
        proposalCount++;

        // Update reviewed/approved state **before** external call
        newProposal.reviewed = false;
        newProposal.approved = false;
        newProposal.autoApproved = false;

        // External call AFTER safe state initialization
        bool autoApproved = consensusContract.createGovernanceProposal(
            proposalType,
            data
        );

        // Update state safely post-external call
        newProposal.reviewed = autoApproved;
        newProposal.approved = autoApproved;
        newProposal.autoApproved = autoApproved;

        // Transfer proposal cost tokens from the proposer to the RewardContract
        bool success = token.transferFrom(
            msg.sender,
            address(rewardContract),
            proposalCost
        );
        if (!success) {
            revert TransferFailed();
        }

        // Deposit rewards for the new proposal in the RewardContract
        rewardContract.depositRewards(currentProposalId);

        emit ProposalCreated(
            currentProposalId,
            msg.sender,
            proposalType,
            data,
            autoApproved
        );
    }

    /// @notice Event emitted when tokens are unstaked
    event TokensUnstaked(
        uint256 indexed proposalId,
        address indexed staker,
        uint256 amount,
        uint256 reward
    );

    /// @notice Unstakes tokens for a specific proposal
    /// @param _proposalId ID of the proposal
    function unstakeTokens(uint256 _proposalId) external nonReentrant {
        Proposal storage proposal = proposals[_proposalId];
        if (!proposal.executed) {
            revert ProposalNotExecuted();
        }

        uint256 stakeAmount = stakedTokens[_proposalId][msg.sender];
        if (stakeAmount == 0) {
            revert NoTokensStaked();
        }

        // Update the totalStakedTokens mapping
        totalStakedTokens[_proposalId] -= stakeAmount;

        uint256 recordedTotalStaked = totalStakedAtExecution[_proposalId];
        uint256 recordedTotalRewards = totalRewardsAtExecution[_proposalId];

        uint256 reward = (stakeAmount * recordedTotalRewards) /
            recordedTotalStaked;

        // Unstake tokens
        stakedTokens[_proposalId][msg.sender] = 0;

        // Before transferring the reward, update the totalDistributedRewards
        totalDistributedRewards[_proposalId] += reward;

        // Transfer tokens back to the voter
        bool success = token.transfer(msg.sender, stakeAmount);
        if (!success) {
            revert TransferFailed();
        }

        // Transfer the calculated reward
        if (reward > 0) {
            rewardContract.transferRewards(msg.sender, _proposalId, reward);
        }

        emit TokensUnstaked(_proposalId, msg.sender, stakeAmount, reward);
    }

    /// @notice Event emitted when rewards are burned
    event RewardsBurned(uint256 indexed proposalId, uint256 residualTokens);

    /// @notice Burns any residual tokens left after reward distribution for a specific proposal
    /// @param _proposalId ID of the proposal
    function burnRewards(uint256 _proposalId) external {
        if (msg.sender != address(consensusContract)) {
            revert CallerNotConsensusContract();
        }
        if (totalStakedTokens[_proposalId] != 0) {
            revert TokensNotUnstaked();
        }

        uint256 recordedTotalRewards = totalRewardsAtExecution[_proposalId];
        uint256 distributedRewards = totalDistributedRewards[_proposalId];

        uint256 residualTokens = recordedTotalRewards - distributedRewards;

        if (residualTokens > 0) {
            rewardContract.burnResidualTokens(_proposalId, residualTokens);
            emit RewardsBurned(_proposalId, residualTokens);
        }
    }

    /// @notice Event emitted when a user votes on a proposal
    event VotedOnProposal(
        uint256 indexed proposalId,
        address indexed voter,
        bool voteFor,
        uint256 stakeAmount
    );

    /// @notice Allows a user to vote for or against a proposal by staking tokens
    /// @param _proposalId ID of the proposal
    /// @param _voteFor Whether to vote for the proposal
    /// @param _stakeAmount Amount of tokens to stake
    function voteOnProposal(
        uint256 _proposalId,
        bool _voteFor,
        uint256 _stakeAmount
    ) external nonReentrant {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.voted[msg.sender]) {
            revert AlreadyVoted();
        }
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }
        if (token.balanceOf(msg.sender) < _stakeAmount) {
            revert InsufficientTokensToStake();
        }
        if (_stakeAmount == 0) {
            revert StakeAmountZero();
        }

        // Retrieve the voting power cap in basis points
        IWBlockToken tokenContract = getTokenContract();
        uint256 votingPowerCapBasisPoints = tokenContract.getSettingValue(
            GovernanceSetting.VotingPowerCap
        );

        // Calculate the actual voting power cap in tokens
        uint256 totalSupply = token.totalSupply();
        uint256 votingPowerCap = (totalSupply * votingPowerCapBasisPoints) /
            10000;

        // Ensure staked amount does not exceed the voting power cap
        if (_stakeAmount > votingPowerCap) {
            revert StakeExceedsVotingPowerCap();
        }
        (bool reviewed, bool approved) = consensusContract
            .getGovernanceProposalReview(_proposalId);
        if (!reviewed) {
            revert ProposalNotReviewed();
        }
        if (!approved) {
            revert ProposalNotApproved();
        }

        // Staking tokens within the cap
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            _stakeAmount
        );
        if (!success) {
            revert TransferFailed();
        }

        // Update the staked tokens mapping for the voter
        stakedTokens[_proposalId][msg.sender] += _stakeAmount;

        // Update the total staked tokens for the proposal
        totalStakedTokens[_proposalId] += _stakeAmount;

        proposal.voted[msg.sender] = true;

        // Staked amount is used as voting power since it's within the cap
        if (_voteFor) {
            proposal.votesFor += _stakeAmount;
        } else {
            proposal.votesAgainst += _stakeAmount;
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;

        // Now the totalVotes includes the current vote, ensuring accurate checks
        if (proposal.proposalType == TYPE_EMERGENCY_RESET_PROPOSAL) {
            // Ensure we only proceed if the proposal meets the required support
            if (
                totalVotes >= (totalSupply * 40) / 100 &&
                proposal.votesFor >= (totalVotes * 80) / 100
            ) {
                executeEmergencyReset(_proposalId);
            }
        }

        emit VotedOnProposal(_proposalId, msg.sender, _voteFor, _stakeAmount);
    }

    /// @notice Executes a proxy contract upgrade
    /// @param _proposalId ID of the proposal
    function executeContractUpgrade(uint256 _proposalId) private {
        if (msg.sender != address(consensusContract)) {
            revert CallerNotConsensusContract();
        }

        Proposal storage proposal = proposals[_proposalId];
        if (proposal.proposalType != TYPE_CONTRACT_UPGRADE_PROPOSAL) {
            revert NotUpgradeProposal();
        }
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Decode the proposal data
        (
            address targetProxy,
            address newImplementation,
            bytes memory data
        ) = abi.decode(proposal.data, (address, address, bytes));

        if (targetProxy == address(0)) {
            revert InvalidTargetProxyAddress();
        }
        if (newImplementation == address(0)) {
            revert InvalidNewImplementationAddress();
        }

        // Execute the upgrade with initialization data
        UUPSUpgradeable(targetProxy).upgradeToAndCall(newImplementation, data);

        // Record stakes and rewards at execution for unstaking purposes
        recordStakesAndRewardsAtExecution(_proposalId);

        // Mark the proposal as executed
        proposal.executed = true;
        proposal.result = true;
    }

    /// @notice Executes an emergency reset proposal by revoking all consensus members
    /// @param _proposalId ID of the proposal
    function executeEmergencyReset(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.proposalType != TYPE_EMERGENCY_RESET_PROPOSAL) {
            revert NotEmergencyResetProposal();
        }

        // Ensure the proposal hasn't been executed yet
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Execute the emergency reset logic
        consensusContract.revokeAllConsensusMembers();

        // Record stakes and rewards at execution for unstaking purposes
        recordStakesAndRewardsAtExecution(_proposalId);

        // Mark the proposal as executed
        proposal.executed = true;
        proposal.result = true;
    }

    /// @notice Records the total staked tokens and rewards at the time of execution for a proposal
    /// @param _proposalId ID of the proposal
    function recordStakesAndRewardsAtExecution(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];
        totalStakedAtExecution[_proposalId] =
            proposal.votesFor +
            proposal.votesAgainst;
        totalRewardsAtExecution[_proposalId] = rewardContract
            .getRewardsForProposal(_proposalId);
    }

    /// @notice Event emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId, bool result);

    /// @notice Executes the main logic for a proposal, including its specific execution logic
    /// @param _proposalId ID of the proposal
    function executeProposalMain(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];

        // Execute proposal logic
        executeProposalLogic(_proposalId);

        // Record stakes and rewards at execution
        totalStakedAtExecution[_proposalId] =
            proposal.votesFor +
            proposal.votesAgainst;
        totalRewardsAtExecution[_proposalId] = rewardContract
            .getRewardsForProposal(_proposalId);

        // Mark the proposal as executed
        proposal.executed = true;
        proposal.result = true;

        emit ProposalExecuted(_proposalId, true);
    }

    /// @notice Event emitted when a proposal is finalized
    event ProposalFinalized(uint256 indexed proposalId);

    /// @notice Finalize a proposal once minimum period ended if it can't be executed because not enough support or votes
    /// @param _proposalId ID of the proposal
    function finalizeProposal(uint256 _proposalId) external {
        if (msg.sender != address(consensusContract)) {
            revert CallerNotConsensusContract();
        }

        Proposal storage proposal = proposals[_proposalId];
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Check if the voting period has concluded
        IWBlockToken tokenContract = getTokenContract();
        uint256 minVotingPeriod = tokenContract.getSettingValue(
            GovernanceSetting.VotingPeriod
        );

        if (block.number < proposal.createdAtBlock + minVotingPeriod) {
            revert VotingPeriodNotEnded();
        }

        proposal.executed = true;
        proposal.result = false;

        // Record stakes and rewards at finalization
        totalStakedAtExecution[_proposalId] =
            proposal.votesFor +
            proposal.votesAgainst;
        totalRewardsAtExecution[_proposalId] = rewardContract
            .getRewardsForProposal(_proposalId);

        emit ProposalFinalized(_proposalId);
    }

    /// @notice Executes a proposal based on its type, either executing its specific logic or delegating to the main execution function
    /// @param _proposalId ID of the proposal
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        if (msg.sender != address(consensusContract)) {
            revert CallerNotConsensusContract();
        }

        // General path for other proposal types
        if (proposal.executed) {
            revert ProposalAlreadyExecuted();
        }

        // Rejection for emergency reset as it's automated
        if (proposal.proposalType == TYPE_EMERGENCY_RESET_PROPOSAL) {
            revert EmergencyResetAutomaticallyExecuted();
        }

        (bool reviewed, bool approved) = consensusContract
            .getGovernanceProposalReview(_proposalId);
        if (!reviewed) {
            revert ProposalNotReviewed();
        }
        if (!approved) {
            revert ProposalNotApproved();
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalSupply = token.totalSupply();

        // Common checks for proposals
        if (totalVotes < (totalSupply / 2)) {
            revert InsufficientVotes();
        }

        if (proposal.votesFor <= proposal.votesAgainst) {
            revert MoreVotesAgainst();
        }

        // Delegate to the main execution function
        executeProposalMain(_proposalId);
    }

    /// @notice Executes the logic for a proposal based on its type
    /// @param _proposalId ID of the proposal
    function executeProposalLogic(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.proposalType == TYPE_GAME_WHITELIST_PROPOSAL) {
            // Decode the game address from the proposal data
            (address gameAddress, string memory gameName) = abi.decode(
                proposal.data,
                (address, string)
            );
            IWBlockToken tokenContract = IWBlockToken(tokenContractAddress);

            // Add the game to the whitelist in the token contract
            tokenContract.addToGameWhitelist(gameAddress, gameName);
        } else if (proposal.proposalType == TYPE_CONSENSUS_MEMBER_PROPOSAL) {
            // Logic for consensus member proposals
            (address member, bool isAddition) = abi.decode(
                proposal.data,
                (address, bool)
            );
            if (isAddition) {
                consensusContract.grantConsensusMemberRole(member);
            } else {
                consensusContract.revokeConsensusMemberRole(member);
            }
        }
        /*  else if (proposal.proposalType == TYPE_EMERGENCY_RESET_PROPOSAL) {
            // Logic for emergency reset proposals
            consensusContract.revokeAllConsensusMembers();
        }  */
        else if (proposal.proposalType == TYPE_SETTING_UPDATE_PROPOSAL) {
            // Logic for setting update proposals
            (GovernanceSetting setting, uint256 proposedValue) = abi.decode(
                proposal.data,
                (GovernanceSetting, uint256)
            );
            if (!isValidSettingValue(setting, proposedValue)) {
                revert InvalidSettingValue();
            }
            IWBlockToken(tokenContractAddress).updateSetting(
                setting,
                proposedValue
            );
        } else if (proposal.proposalType == TYPE_CONTRACT_UPGRADE_PROPOSAL) {
            executeContractUpgrade(_proposalId);
        }
    }

    // Constants for general values
    uint256 internal constant ONE_MILLION = 1e6;
    uint256 internal constant ONE_BILLION = 1e9;
    uint256 internal constant MIN_BLOCKS = 10;
    uint256 internal constant MAX_BLOCKS = 1e8;

    /// @notice Checks if a proposed value for a specific setting is valid
    /// @param _setting Setting to check
    /// @param _value Proposed value for the setting
    /// @return Whether the proposed value is valid
    function isValidSettingValue(
        GovernanceSetting _setting,
        uint256 _value
    ) private pure returns (bool) {
        // Each condition checks the proposed value against the allowed range for that setting
        if (_setting == GovernanceSetting.LiquidityFee) {
            // Liquidity Fee: 0.1% to 5% (in basis points)
            return _value >= 10 && _value <= 500;
        } else if (_setting == GovernanceSetting.BurnFee) {
            // Burn Fee: 0.1% to 3% (in basis points)
            return _value >= 10 && _value <= 300;
        } else if (_setting == GovernanceSetting.SwapLimit) {
            // Swap Limit: 1M to 1B of available token (full token unit)
            return _value >= ONE_MILLION && _value <= ONE_BILLION; // 1M to 1B tokens
        } else if (_setting == GovernanceSetting.TransferLimit) {
            // Global Transfer Limits: 0.01% to 10% of total token supply (in basis points)
            return _value >= 1 && _value <= 1000;
        } else if (_setting == GovernanceSetting.VotingPowerCap) {
            // Voting Power Cap: 0.01% to 40% of total token supply (in basis points)
            return _value >= 1 && _value <= 4000;
        } else if (_setting == GovernanceSetting.ProposalCost) {
            // Proposal Cost: 0.01% to 1% of total token supply (in basis points)
            return _value >= 1 && _value <= 100;
        } else if (_setting == GovernanceSetting.CommunityTax) {
            // Community Tax: 0.5% to 5% of game's earnings (in basis points)
            return _value >= 50 && _value <= 500;
        } else if (_setting == GovernanceSetting.DeveloperTax) {
            // Developer Tax: Up to 5% of game's winnings (in basis points)
            return _value >= 1 && _value <= 500;
        } else if (_setting == GovernanceSetting.RewardThreshold) {
            // Reward Threshold: 1M to 1B available tokens (full token unit)
            return _value >= ONE_MILLION && _value <= ONE_BILLION; // 1M to 1B tokens
        } else if (_setting == GovernanceSetting.CooldownMinBlock) {
            // Cooldown Min Block: 10 to 100k blocks minimum between each sell swap
            return _value >= 10 && _value <= 100000; // 10 to 100K blocks
        } else if (_setting == GovernanceSetting.LiquidityThreshold) {
            // Liquidity Threshold: 1M to 1B available tokens (full token unit)
            return _value >= ONE_MILLION && _value <= ONE_BILLION; // 1M to 1B tokens
        } else if (_setting == GovernanceSetting.VotingPeriod) {
            // Cooldown Min Block: 10 to 100M blocks minimum between each sell swap
            return _value >= MIN_BLOCKS && _value <= MAX_BLOCKS; // 10 to 100M blocks
        }

        // Default to false for unhandled settings
        return false;
    }

    /// @notice Event emitted when a game whitelist proposal is created
    event GameWhitelistProposalCreated(
        uint256 indexed proposalId,
        address indexed gameAddress,
        string gameName
    );

    /// @notice Creates a proposal to add a game to the whitelist
    /// @param gameAddress Address of the game
    /// @param gameName Name of the game
    function createGameWhitelistProposal(
        address gameAddress,
        string memory gameName
    ) external nonReentrant {
        bytes memory data = abi.encode(gameAddress, gameName);
        createProposal(TYPE_GAME_WHITELIST_PROPOSAL, data);

        emit GameWhitelistProposalCreated(
            proposalCount - 1,
            gameAddress,
            gameName
        );
    }

    /// @notice Event emitted when a consensus member proposal is created
    event ConsensusMemberProposalCreated(
        uint256 indexed proposalId,
        address indexed member,
        bool isAddition
    );

    /// @notice Creates a proposal to add the sender as a consensus member
    function createConsensusAddingProposal() external nonReentrant {
        // Check if the address is already a consensus member
        if (consensusContract.isConsensusMember(msg.sender)) {
            revert AlreadyConsensusMember();
        }

        bytes memory data = abi.encode(msg.sender, true);
        createProposal(TYPE_CONSENSUS_MEMBER_PROPOSAL, data);

        emit ConsensusMemberProposalCreated(
            proposalCount - 1,
            msg.sender,
            true
        );
    }

    /// @notice Creates a proposal to remove a consensus member
    /// @param member Address of the consensus member to be removed
    function createConsensusRemovalProposal(
        address member
    ) external nonReentrant {
        bytes memory data = abi.encode(member, false);
        createProposal(TYPE_CONSENSUS_MEMBER_PROPOSAL, data);
    }

    /// @notice Event emitted when an emergency reset proposal is created
    event EmergencyResetProposalCreated(uint256 indexed proposalId);

    /// @notice Creates a proposal for an emergency reset
    function createEmergencyResetProposal() external nonReentrant {
        bytes memory data; // No need to assign an empty value
        createProposal(TYPE_EMERGENCY_RESET_PROPOSAL, data);

        emit EmergencyResetProposalCreated(proposalCount - 1);
    }

    /// @notice Event emitted when a contract upgrade proposal is created
    event ContractUpgradeProposalCreated(
        uint256 indexed proposalId,
        address indexed targetProxy,
        address indexed newImplementation
    );

    /// @notice Creates a proposal for a contract upgrade
    /// @param targetProxy Address of the proxy contract to upgrade
    /// @param newImplementation Address of the new implementation
    /// @param data Initialization data for the new implementation (can be empty)
    function createContractUpgradeProposal(
        address targetProxy,
        address newImplementation,
        bytes memory data
    ) external nonReentrant {
        if (targetProxy == address(0)) {
            revert InvalidTargetAddress();
        }
        if (newImplementation == address(0)) {
            revert InvalidNewImplementationAddress();
        }

        // Encode both the addresses and data for the proposal
        bytes memory proposalData = abi.encode(
            targetProxy,
            newImplementation,
            data
        );

        createProposal(TYPE_CONTRACT_UPGRADE_PROPOSAL, proposalData);

        emit ContractUpgradeProposalCreated(
            proposalCount - 1,
            targetProxy,
            newImplementation
        );
    }

    /// @notice Event emitted when a setting proposal is created
    event SettingProposalCreated(
        uint256 indexed proposalId,
        GovernanceSetting indexed setting,
        uint256 proposedValue
    );

    /// @notice Creates a proposal to update a governance setting
    /// @param setting Setting to be updated
    /// @param proposedValue Proposed value for the setting
    function createSettingProposal(
        GovernanceSetting setting,
        uint256 proposedValue
    ) external nonReentrant {
        bytes memory data = abi.encode(setting, proposedValue);
        createProposal(TYPE_SETTING_UPDATE_PROPOSAL, data);

        emit SettingProposalCreated(proposalCount - 1, setting, proposedValue);
    }
}
