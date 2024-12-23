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

/// @custom:security-contact security@winnerblock.io
/// @title ILiquidityManagedToken Interface
/// @notice Interface for managing liquidity-related operations for a token.
interface ILiquidityManagedToken {
    /// @notice Retrieves the address of the Uniswap router contract.
    /// @return The address of the Uniswap router.
    function getUniswapRouterAddress() external view returns (address);

    /// @notice Checks whether the initial liquidity has been added to Uniswap.
    /// @return Indicates whether initial liquidity has been added (true or false).
    function getInitialLiquidityStatus() external view returns (bool);

    /// @notice Adds liquidity to the Uniswap liquidity pool.
    /// @param amount The amount of tokens to add as liquidity.
    function addLiquidityToUniswap(uint256 amount) external;

    /// @notice Handles the process for providing initial liquidity.
    /// @dev This function is typically called during the setup phase to bootstrap the liquidity pool.
    function initialLiquidity() external;
}
