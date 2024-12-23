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
/// @title IUUPSProxy Interface
/// @notice Interface for upgrading the implementation of a proxy contract using the UUPS (Universal Upgradeable Proxy Standard) pattern.
interface IUUPSProxy {
    /// @notice Upgrades the proxy contract to a new implementation and optionally executes a function call.
    /// @dev This function allows upgrading the implementation of the proxy and executing a setup call in a single transaction.
    /// @param newImplementation The address of the new implementation contract.
    /// @param data Encoded function call data to execute on the new implementation (can be empty).
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external;
}
