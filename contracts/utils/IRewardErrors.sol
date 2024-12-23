// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/// @custom:security-contact security@winnerblock.io
/// @title Reward Errors Interface
/// @notice Common error declarations for the WinnerBlock ecosystem
interface IRewardErrors {
    /// @notice Thrown when a function is called by an unauthorized account.
    error Unauthorized();

    /// @notice Thrown when rewards allocated for a proposal are insufficient.
    error InsufficientProposalRewards(uint256 allocated, uint256 required);

    /// @notice Thrown when the unreserved balance is insufficient to meet the reward threshold.
    error InsufficientUnreservedBalance(uint256 available, uint256 threshold);

    /// @notice Thrown when the burn amount exceeds the unallocated rewards for a proposal.
    error BurnAmountExceedsRewards(uint256 available, uint256 burnAmount);

    /// @notice Thrown when the transfer reward failed during unstake
    error TransferRewardFailed();
}
