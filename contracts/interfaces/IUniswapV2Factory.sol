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
/// @title IUniswapV2Factory Interface
/// @notice Interface for the Uniswap V2 Factory contract to create liquidity pairs.
interface IUniswapV2Factory {
    /// @notice Creates a new liquidity pair for two tokens.
    /// @dev The pair contract is deployed and registered within the Uniswap V2 Factory.
    /// @param tokenA The address of the first token in the pair.
    /// @param tokenB The address of the second token in the pair.
    /// @return The address of the newly created pair contract.
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address);
}
