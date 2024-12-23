// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/// @custom:security-contact security@winnerblock.io
/// @title Token Errors Interface
/// @notice Common error declarations for the WinnerBlock ecosystem
interface ITokenErrors {
    /// @notice Thrown when the caller does not have the admin role.
    error CallerNotAdmin();

    /// @notice Thrown when the deployment phase has already ended.
    error DeploymentAlreadyEnded();

    /// @notice Thrown when the caller does not have sufficient token balance.
    error InsufficientBalance(uint256 available, uint256 required);

    /// @notice Thrown when the transfer amount exceeds the global transfer limit.
    error TransferExceedsGlobalLimit(uint256 attempted, uint256 limit);

    /// @notice Thrown when the transfer is not a sell transaction with the community pair.
    error NotSellTransactionWithCommunityPair();

    /// @notice Thrown when the initial liquidity has not yet been provided.
    error InitialLiquidityNotProvided();

    /// @notice Thrown when the cooldown period has not passed for a token transfer.
    error CooldownPeriodNotPassed(uint256 currentBlock, uint256 requiredBlock);

    /// @notice Thrown when the transfer exceeds the allowed swap limit.
    error TransferExceedsSwapLimit(uint256 attempted, uint256 limit);

    /// @notice Thrown when the caller does not have the governance role.
    error CallerNotGovernance();

    /// @notice Thrown when the caller does not have the consensus role.
    error CallerNotConsensus();

    /// @notice Thrown when the game is not active or whitelisted.
    error GameNotActiveOrWhitelisted();

    /// @notice Thrown when the developer fee exceeds the maximum allowed limit.
    error DevFeeExceedsMax(uint256 attempted, uint256 maximum);

    /// @notice Thrown when the transfer of the community share fails.
    error CommunityShareTransferFailed();

    /// @notice Thrown when the transfer of the developer share fails.
    error DeveloperShareTransferFailed();

    /// @notice Thrown when the transfer of the winner's reward fails.
    error WinnerRewardTransferFailed();
}
