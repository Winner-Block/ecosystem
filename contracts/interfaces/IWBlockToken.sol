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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GovernanceSetting} from "../utils/GovernanceTypes.sol";

/// @custom:security-contact security@winnerblock.io
/// @title IWBlockToken Interface
/// @notice Interface for the TWB1 token, including governance, game management, and ERC20 operations.
interface IWBlockToken is IERC20 {
    /// @notice Updates a governance setting with a specified value.
    /// @param key The key representing the governance setting to be updated.
    /// @param value The new value to assign to the governance setting.
    function updateSetting(GovernanceSetting key, uint256 value) external;

    /// @notice Grants the consensus role to a specified account.
    /// @param account The address to be granted the consensus role.
    function grantConsensusRole(address account) external;

    /// @notice Grants the governance role to a specified account.
    /// @param account The address to be granted the governance role.
    function grantGovernanceRole(address account) external;

    /// @notice Retrieves the value of a specific governance setting.
    /// @param key The key representing the governance setting.
    /// @return The value assigned to the governance setting.
    function getSettingValue(
        GovernanceSetting key
    ) external view returns (uint256);

    /// @notice Adds a game to the whitelist with its associated name.
    /// @param gameAddress The address of the game to be added to the whitelist.
    /// @param gameName The name of the game.
    function addToGameWhitelist(
        address gameAddress,
        string memory gameName
    ) external;

    /// @notice Retrieves the total supply of the token.
    /// @return The total supply of the token.
    function totalSupply() external view returns (uint256);

    /// @notice Retrieves the number of decimals used for the token.
    /// @return The number of decimals (e.g., 18).
    function decimals() external view returns (uint8);

    /// @notice Transfers tokens on behalf of another account.
    /// @param sender The address sending the tokens.
    /// @param recipient The address receiving the tokens.
    /// @param amount The amount of tokens to transfer.
    /// @return Indicates whether the transfer was successful (true or false).
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice Burns a specified amount of tokens.
    /// @param burnAmount The amount of tokens to burn.
    function burnTokens(uint256 burnAmount) external;

    /// @notice Pauses all token transfers and operations.
    /// @dev Can only be called by an authorized account.
    function pause() external;

    /// @notice Unpauses all token transfers and operations.
    /// @dev Can only be called by an authorized account.
    function unpause() external;

    /// @notice Removes a game from the whitelist.
    /// @param gameAddress The address of the game to be removed.
    function removeFromGameWhitelist(address gameAddress) external;

    /// @notice Approves a spender to transfer up to a specified amount of tokens on behalf of the caller.
    /// @param spender The address of the spender.
    /// @param amount The amount of tokens to approve.
    /// @return Indicates whether the approval was successful (true or false).
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Checks if a specific game is currently active.
    /// @param gameAddress The address of the game to check.
    /// @return Indicates whether the game is active (true or false).
    function isGameActive(address gameAddress) external view returns (bool);
}
