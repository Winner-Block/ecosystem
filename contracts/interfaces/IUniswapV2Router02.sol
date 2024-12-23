// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

/**
 * @title WinnerBlock WBlock Interface
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

/// @custom:security-contact security@winnerblock.io/// @title IUniswapV2Router02 Interface
/// @notice Interface for interacting with the Uniswap V2 Router, including liquidity management and token swapping functions.
interface IUniswapV2Router02 {
    /// @notice Adds liquidity to an ETH-token pair.
    /// @dev This function deposits both ETH and the specified token to create or add liquidity to a Uniswap pool.
    /// @param token The address of the ERC20 token.
    /// @param amountTokenDesired The amount of the token to deposit into the pool.
    /// @param amountTokenMin The minimum amount of the token to add to the pool (slippage protection).
    /// @param amountETHMin The minimum amount of ETH to add to the pool (slippage protection).
    /// @param to The address that will receive the liquidity tokens.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amountToken The actual amount of the token added to the pool.
    /// @return amountETH The actual amount of ETH added to the pool.
    /// @return liquidity The amount of liquidity tokens received.
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /// @notice Retrieves the address of the Uniswap V2 Factory contract.
    /// @return The address of the Uniswap V2 Factory.
    function factory() external pure returns (address);

    /// @notice Retrieves the address of the Wrapped ETH (WETH) token contract.
    /// @return The address of the WETH token.
    function WETH() external pure returns (address);

    /// @notice Swaps an exact amount of tokens for as much ETH as possible.
    /// @dev This function allows converting tokens into ETH using a specific path.
    /// @param amountIn The exact amount of input tokens to swap.
    /// @param amountOutMin The minimum amount of ETH to receive (slippage protection).
    /// @param path An array of token addresses representing the swap path.
    /// @param to The address to receive the swapped ETH.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amounts An array containing the amounts for each token in the swap path.
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps an exact amount of ETH for as many tokens as possible.
    /// @dev This function allows converting ETH into tokens using a specific path.
    /// @param amountOutMin The minimum amount of tokens to receive (slippage protection).
    /// @param path An array of token addresses representing the swap path.
    /// @param to The address to receive the swapped tokens.
    /// @param deadline The timestamp by which the transaction must be completed.
    /// @return amounts An array containing the amounts for each token in the swap path.
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}
