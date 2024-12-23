// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/// @custom:security-contact security@winnerblock.io
/// @title Consensus Errors Interface
/// @notice Common error declarations for the WinnerBlock ecosystem
interface IConsensusErrors {
    /// @notice Error thrown when caller does not have the required admin role
    error CallerIsNotAdmin();

    /// @notice Error thrown when caller does not have the governance role
    error CallerIsNotGovernance();

    /// @notice Error thrown when caller does not have the consensus member role
    error CallerIsNotConsensusMember();

    /// @notice Error thrown when founder address cannot be added or removed
    error InvalidOperationOnFounder();

    /// @notice Error thrown when proposal is already reviewed
    error ProposalAlreadyReviewed();

    /// @notice Error thrown when proposal is already finalized
    error ProposalAlreadyFinalized();

    /// @notice Error thrown when proposal must be reviewed first
    error ProposalNotReviewed();

    /// @notice Error thrown when proposal must be approved first
    error ProposalNotApproved();

    /// @notice Error thrown when caller has already voted
    error AlreadyVoted();

    /// @notice Error thrown when proposal is already executed
    error ProposalAlreadyExecuted();

    /// @notice Error thrown when execution of a proposal failed
    error ExecutionFailed();

    /// @notice Error thrown when game is not active or not whitelisted
    error GameNotActiveOrNotWhitelisted();

    /// @notice Error thrown when there are no entries to remove
    error NoEntriesToRemove();
}
