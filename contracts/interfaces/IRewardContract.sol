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

/// @custom:security-contact security@winnerblock.io/// @title IRewardContract Interface
/// @notice Interface for managing reward-related operations for proposals.
interface IRewardContract {
    /// @notice Transfers rewards to a specified address for a given proposal.
    /// @param to The address to which the rewards will be transferred.
    /// @param _proposalId The unique identifier of the proposal.
    /// @param rewardAmount The amount of rewards to transfer.
    function transferRewards(
        address to,
        uint256 _proposalId,
        uint256 rewardAmount
    ) external;

    /// @notice Retrieves the reward amount allocated for a specific proposal.
    /// @param _proposalId The unique identifier of the proposal.
    /// @return The amount of rewards allocated for the proposal.
    function getRewardsForProposal(
        uint256 _proposalId
    ) external view returns (uint256);

    /// @notice Deposits rewards into the contract for a specific proposal.
    /// @param _proposalId The unique identifier of the proposal.
    function depositRewards(uint256 _proposalId) external;

    /// @notice Burns residual tokens associated with a specific proposal.
    /// @param _proposalId The unique identifier of the proposal.
    /// @param amount The amount of tokens to burn.
    function burnResidualTokens(uint256 _proposalId, uint256 amount) external;
}
