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
/// @title IConsensusContract Interface
/// @notice Interface for managing consensus members and governance proposals.
interface IConsensusContract {
    /// @notice Grants the consensus member role to a new member.
    /// @param _newMember The address of the new consensus member.
    function grantConsensusMemberRole(address _newMember) external;

    /// @notice Revokes the consensus member role from an existing member.
    /// @param _member The address of the member to revoke the role from.
    function revokeConsensusMemberRole(address _member) external;

    /// @notice Creates a new governance proposal.
    /// @param proposalType The type/category of the governance proposal.
    /// @param data Encoded data related to the governance proposal.
    /// @return autoApproved Indicates whether the proposal was automatically approved.
    function createGovernanceProposal(
        uint256 proposalType,
        bytes memory data
    ) external returns (bool autoApproved);

    /// @notice Retrieves the review status and approval status of a governance proposal.
    /// @param _proposalId The unique ID of the governance proposal.
    /// @return reviewed Indicates whether the proposal has been reviewed.
    /// @return approved Indicates whether the proposal has been approved.
    function getGovernanceProposalReview(
        uint256 _proposalId
    ) external view returns (bool reviewed, bool approved);

    /// @notice Revokes all current consensus members.
    /// @dev This action removes all members assigned with the consensus member role.
    function revokeAllConsensusMembers() external;

    /// @notice Returns the total number of consensus members.
    /// @return The number of consensus members.
    function consensusMemberCount() external view returns (uint256);

    /// @notice Checks if an address is a consensus member.
    /// @param _member The address to check.
    /// @return Indicates whether the given address is a consensus member.
    function isConsensusMember(address _member) external view returns (bool);
}
