// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/// @custom:security-contact security@winnerblock.io
/// @title Governance Errors Interface
/// @notice Common error declarations for the WinnerBlock ecosystem
interface IGovernanceErrors {
    /// @notice Error raised when the caller is not the consensus contract
    error CallerNotConsensusContract();

    /// @notice Error raised when the proposal is not reviewed by consensus
    error ProposalNotReviewed();

    /// @notice Error raised when the proposal is not approved by consensus
    error ProposalNotApproved();

    /// @notice Error raised when the proposal already executed
    error ProposalAlreadyExecuted();

    /// @notice Error raised when insufficient tokens are available for staking
    error InsufficientTokensForStake();

    /// @notice Error raised when stake amount exceeds the voting power cap
    error StakeExceedsVotingPowerCap();

    /// @notice Error raised when insufficient votes are cast for a proposal
    error InsufficientVotes();

    /// @notice Error raised when an invalid setting value is provided
    error InvalidSettingValue();

    /// @notice Error raised when the proposal is not yet executed
    error ProposalNotExecuted();

    /// @notice Error raised when no tokens are staked for the proposal
    error NoTokensStaked();

    /// @notice Error raised when not all tokens are unstaked
    error TokensNotUnstaked();

    /// @notice Error raised when the user has already voted
    error AlreadyVoted();

    /// @notice Error raised when insufficient tokens are available to stake
    error InsufficientTokensToStake();

    /// @notice Error raised when the stake amount must be greater than zero
    error StakeAmountZero();

    /// @notice Error raised when a target address is invalid
    error InvalidTargetAddress();

    /// @notice Error raised when the proposal is not an emergency reset proposal
    error NotEmergencyResetProposal();

    /// @notice Error raised when the minimum voting period has not ended
    error VotingPeriodNotEnded();

    /// @notice Error raised when the sender is already a consensus member
    error AlreadyConsensusMember();

    /// @notice Error raised when the target proxy address provided is invalid
    error InvalidTargetProxyAddress();

    /// @notice Error raised when the proposal is not of type "upgrade proposal"
    error NotUpgradeProposal();

    /// @notice Error raised when the new implementation address is invalid
    error InvalidNewImplementationAddress();

    /// @notice Error raised when more votes are cast against the proposal than in favor
    error MoreVotesAgainst();

    /// @notice Error thrown when an emergency reset is executed automatically
    error EmergencyResetAutomaticallyExecuted();

    /// @notice Error thrown when transfer of tokens failed
    error TransferFailed();
}
