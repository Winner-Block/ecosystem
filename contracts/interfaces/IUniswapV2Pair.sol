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
/// @title IUniswapV2Pair Interface
/// @notice Interface for interacting with Uniswap V2 liquidity pair contracts.
interface IUniswapV2Pair {
    /// @notice Retrieves the reserves of the liquidity pair.
    /// @dev Provides the current reserves of the two tokens in the pair along with the last updated block timestamp.
    /// @return reserve0 The reserve amount of the first token (`token0`) in the pair.
    /// @return reserve1 The reserve amount of the second token (`token1`) in the pair.
    /// @return blockTimestampLast The last block timestamp when reserves were updated.
    function getReserves()
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast);

    /// @notice Retrieves the address of the first token in the pair.
    /// @return The address of `token0`.
    function token0() external view returns (address);

    /// @notice Retrieves the address of the second token in the pair.
    /// @return The address of `token1`.
    function token1() external view returns (address);
}