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
/// @title IGovernanceContract Interface
/// @notice Interface for managing and executing governance proposals.
interface IGovernanceContract {
    /// @notice Updates the status of a specific proposal.
    /// @param proposalId The unique identifier of the proposal.
    /// @param reviewed Indicates whether the proposal has been reviewed.
    /// @param approved Indicates whether the proposal has been approved.
    function updateProposalStatus(
        uint256 proposalId,
        bool reviewed,
        bool approved
    ) external;

    /// @notice Executes a specific proposal.
    /// @param _proposalId The unique identifier of the proposal to be executed.
    function executeProposal(uint256 _proposalId) external;

    /// @notice Finalizes a specific proposal.
    /// @dev This function marks the end of a proposal's lifecycle.
    /// @param _proposalId The unique identifier of the proposal to be finalized.
    function finalizeProposal(uint256 _proposalId) external;

    /// @notice Burns any unclaimed rewards associated with a specific proposal.
    /// @param _proposalId The unique identifier of the proposal for which rewards will be burned.
    function burnRewards(uint256 _proposalId) external;

    /// @notice Returns the total number of governance proposals created.
    /// @return The number of governance proposals.
    function proposalCount() external view returns (uint256);
}
