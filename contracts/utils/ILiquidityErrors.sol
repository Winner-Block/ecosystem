// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/// @custom:security-contact security@winnerblock.io
/// @title Liquidity Errors Interface
/// @notice Common error declarations for the WinnerBlock ecosystem
interface ILiquidityErrors {
    /// @notice Thrown when the token address provided is zero
    error InvalidTokenAddress();

    /// @notice Thrown when the caller is not authorized for the action
    error Unauthorized();

    /// @notice Thrown when the initial liquidity has already been added
    error InitialLiquidityAlreadyAdded();

    /// @notice Thrown when the token balance is insufficient for the operation
    error InsufficientTokenBalance(uint256 available, uint256 required);

    /// @notice Thrown when the ETH balance is insufficient for the operation
    error InsufficientEthBalance(uint256 available, uint256 required);

    /// @notice Thrown when the Uniswap router address is invalid
    error InvalidUniswapRouterAddress();

    /// @notice Thrown when the caller is not the token contract
    error CallerNotTokenContract();

    /// @notice Thrown when the initial liquidity has not yet been added
    error InitialLiquidityNotProvided();

    /// @notice Thrown when the token balance in the contract is insufficient
    error InsufficientContractTokenBalance(uint256 available, uint256 required);

    /// @notice Thrown when the Uniswap router address is invalid
    error UniswapRouterNotSet();

    /// @notice Thrown when approval of tokens fail
    error ApprovalFailed();
}
