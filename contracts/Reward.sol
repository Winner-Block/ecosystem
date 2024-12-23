// SPDX-License-Identifier: GPL-3.0
/// @notice Contract managing gaming reward
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IWBlockToken} from "./interfaces/IWBlockToken.sol";
import {IGovernanceContract} from "./interfaces/IGovernanceContract.sol";
import {GovernanceSetting} from "./utils/GovernanceTypes.sol";
import {IRewardErrors} from "./utils/IRewardErrors.sol";

/**
 * @title WinnerBlock Reward Contract
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
contract RewardContract is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IRewardErrors
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Ecosystem Token
    IWBlockToken public token;

    /// @notice Governance contract manage rewards
    address public governanceContract;

    /// @notice Mapping of proposal IDs to their associated reward amounts.
    mapping(uint256 proposalId => uint256 rewardAmount) public proposalRewards;

    uint8 private tokenDecimals;

    /// @notice Storage gap for upgradeable contract
    uint256[50] private __gap;

    /// @notice Emitted when the contract is initialized
    event Initialized(
        address indexed tokenAddress,
        address indexed governanceContract,
        address indexed owner
    );

    /// @notice Initializes the upgradeable contract
    /// @param _tokenAddress The address of the token contract
    /// @param _governanceContract The address of the governance contract
    function initialize(
        address _tokenAddress,
        address _governanceContract,
        address initialOwner
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        token = IWBlockToken(_tokenAddress);
        governanceContract = _governanceContract;
        tokenDecimals = token.decimals();

        emit Initialized(_tokenAddress, _governanceContract, initialOwner);
    }

    /// @notice Authorize upgrade function for UUPSUpgradeable
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /// @notice Calculate total reserved rewards
    /// @return Total reserved rewards
    function totalReservedRewards() public view returns (uint256) {
        uint256 totalReserved;
        IGovernanceContract governance = IGovernanceContract(
            governanceContract
        );
        uint256 highestProposalId = governance.proposalCount();
        for (uint256 i; i <= highestProposalId; ++i) {
            totalReserved += proposalRewards[i];
        }
        return totalReserved;
    }

    /// @notice Emitted when rewards are transferred for a proposal
    event RewardsTransferred(
        address indexed to,
        uint256 indexed proposalId,
        uint256 rewardAmount
    );

    /// @notice Transfer rewards for a proposal
    /// @param to Recipient of the rewards
    /// @param _proposalId Proposal ID
    /// @param rewardAmount Amount of rewards to transfer
    function transferRewards(
        address to,
        uint256 _proposalId,
        uint256 rewardAmount
    ) external {
        if (msg.sender != governanceContract) {
            revert Unauthorized();
        }
        uint256 allocatedRewardAmount = proposalRewards[_proposalId];
        if (allocatedRewardAmount < rewardAmount) {
            revert InsufficientProposalRewards(
                allocatedRewardAmount,
                rewardAmount
            );
        }

        proposalRewards[_proposalId] -= rewardAmount;
        bool success = token.transfer(to, rewardAmount);
        if (!success) {
            revert TransferRewardFailed();
        }

        emit RewardsTransferred(to, _proposalId, rewardAmount);
    }

    /// @notice Emitted when rewards are deposited for a proposal
    event RewardsDeposited(uint256 indexed proposalId, uint256 rewardAmount);

    /// @notice Deposit rewards for a proposal
    /// @param _proposalId Proposal ID
    function depositRewards(uint256 _proposalId) external {
        if (msg.sender != governanceContract) {
            revert Unauthorized();
        }
        uint256 rewardThreshold = token.getSettingValue(
            GovernanceSetting.RewardThreshold
        ) * (10 ** tokenDecimals);

        uint256 totalReserved = totalReservedRewards();
        uint256 availableBalance = token.balanceOf(address(this));
        if (availableBalance - totalReserved < rewardThreshold) {
            revert InsufficientUnreservedBalance(
                availableBalance - totalReserved,
                rewardThreshold
            );
        }

        proposalRewards[_proposalId] += rewardThreshold;

        emit RewardsDeposited(_proposalId, rewardThreshold);
    }

    /// @notice Get rewards allocated for a proposal
    /// @param _proposalId Proposal ID
    /// @return Allocated rewards for the proposal
    function getRewardsForProposal(
        uint256 _proposalId
    ) external view returns (uint256) {
        return proposalRewards[_proposalId];
    }

    /// @notice Get the reward balance of the contract
    /// @return Balance of rewards in the contract
    function getRewardBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Emitted when residual tokens are burned
    event ResidualTokensBurned(uint256 indexed proposalId, uint256 amount);

    /// @notice Burn residual tokens for a proposal
    /// @param _proposalId Proposal ID
    /// @param amount Amount of tokens to burn
    function burnResidualTokens(uint256 _proposalId, uint256 amount) external {
        if (msg.sender != governanceContract) {
            revert Unauthorized();
        }

        if (proposalRewards[_proposalId] < amount) {
            revert BurnAmountExceedsRewards(
                proposalRewards[_proposalId],
                amount
            );
        }

        proposalRewards[_proposalId] -= amount;
        token.burnTokens(amount);

        emit ResidualTokensBurned(_proposalId, amount);
    }

    /// @notice Emitted when the governance contract address is updated
    event GovernanceContractUpdated(address indexed newGovernanceContract);

    /// @notice Set a governance contract address
    /// @param _governanceContract Governance contract address
    function setGovernanceContract(
        address _governanceContract
    ) external nonReentrant onlyOwner {
        governanceContract = _governanceContract;

        emit GovernanceContractUpdated(_governanceContract);
    }
}
