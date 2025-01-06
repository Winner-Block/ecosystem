// SPDX-License-Identifier: GPL-3.0
/// @notice Ecosystem's erc20 token contract
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILiquidityManagedToken} from "./interfaces/ILiquidityManagedToken.sol";
import {GovernanceSetting} from "./utils/GovernanceTypes.sol";
import {ITokenErrors} from "./utils/ITokenErrors.sol";

/**
 * @title WinnerBlock WBlock Token Contract
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
contract WBlockToken is
    Initializable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    ERC20PausableUpgradeable,
    UUPSUpgradeable,
    ITokenErrors
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Storage gap for upgradeable contract
    uint256[50] private __gap;

    /// @notice Consensus Contract
    bytes32 public constant CONSENSUS_ROLE = keccak256("CONSENSUS_ROLE");

    /// @notice Governance Contract
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice LiquidityManagedToken Contract
    address public liquidityManager;

    /// @notice Address of the pair contract used for automatic token liquidity pool
    address public pairAddress;

    /// @notice Accumulated fees on sell swaps designated for liquidity provision
    uint256 public accumulatedLiquidityFees;

    /// @notice Reward contract used for community redistribution of rewards
    address public communityPoolAddress;

    struct GameInfo {
        bool isActive;
        string name;
    }

    /// @notice Mapping of player addresses to their associated game information.
    mapping(address player => GameInfo gameInfo) public gameDetails;
    address[] private whitelistedGames;
    bool private _isDeploying;

    mapping(address seller => uint256 lastBlockSold) private lastSellBlock;

    mapping(GovernanceSetting settingType => uint256 settingValue)
        private _settings;

    /// @notice Event emitted when the default governance settings are set.
    event DefaultSettingsSet();

    function _setDefaultSettings() private {
        _settings[GovernanceSetting.LiquidityFee] = 500; // 5%; Liquidity Fee (0): 0.1% to 5% (in basis points)
        _settings[GovernanceSetting.BurnFee] = 300; // 3%; Burn Fee (1): 0.1% to 3% (in basis points)
        _settings[GovernanceSetting.SwapLimit] = 20000000; // 20M tokens; Sell Swap Limit (2): 1M to 1B of available token (full token unit)
        _settings[GovernanceSetting.TransferLimit] = 1000; // 10%; Global Transfer Limits (3): 0.01% to 10% of total token supply (in basis points)
        _settings[GovernanceSetting.VotingPowerCap] = 4000; // 40%; Voting Power Cap (4): 0.01% to 40% of total token supply (in basis points)
        _settings[GovernanceSetting.ProposalCost] = 1; // 0.01%; Proposal Cost (5): 0.01% to 1% of total token supply (in basis points)
        _settings[GovernanceSetting.CommunityTax] = 500; // 5%; Community Tax (6): 0.5% to 5% of game's earnings (in basis points)
        _settings[GovernanceSetting.DeveloperTax] = 500; // 5%; Developer Tax (7): Up to 5% of game's winnings (in basis points)
        _settings[GovernanceSetting.RewardThreshold] = 1000000; // 1M tokens; Reward Threshold (8): 1M to 1B available tokens (full token unit)
        _settings[GovernanceSetting.CooldownMinBlock] = 30000; // 30k Blocks (about 1 day on bsc); Cooldown Min Block (9): 10 to 100000 blocks
        _settings[GovernanceSetting.LiquidityThreshold] = 1000000; // 1M tokens; Liquidity Threshold (10): 1M to 1B available tokens (full token unit)
        _settings[GovernanceSetting.VotingPeriod] = 900000; // 900k blocks (about 30 days on bsc); Voting Period (11): 10 to 100M blocks

        emit DefaultSettingsSet();
    }

    /// @notice Returns the number of decimals used for token calculations
    /// @return The number of decimals (9) for the token
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    /// @notice The initial supply of tokens set to 7 billion full unit tokens (7e9).
    uint256 public constant INITIAL_SUPPLY = 7e9;

    /// @notice Event emitted when the contract is initialized.
    event Initialized(address indexed admin, uint256 indexed initialSupply);

    /// @notice Initializes the contract and sets up the token parameters
    /// @dev This function sets the token name, symbol, and initial settings
    /// It also grants admin rights, enables reentrancy protection, and mints the initial supply
    /// @param admin The address that will receive the initial supply and be assigned as the admin
    function initialize(address admin) external initializer {
        __ERC20_init("Winner Block", "WBLOCK");
        __ReentrancyGuard_init();
        __AccessControl_init();
        __ERC20Pausable_init();

        _isDeploying = true;

        _mint(admin, INITIAL_SUPPLY * 10 ** uint256(decimals()));
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setDefaultSettings();

        emit Initialized(admin, INITIAL_SUPPLY);
    }

    /// @notice Event emitted when the deployment phase ends.
    event DeploymentEnded();

    /// @notice Marks the end of the deployment phase
    function deployEnd() external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        if (_isDeploying) {
            _isDeploying = false;
            emit DeploymentEnded();
        } else if (!_isDeploying) {
            revert DeploymentAlreadyEnded();
        }
    }

    /// @notice Event emitted when the liquidity contract is updated.
    event LiquidityContractUpdated(address indexed newLiquidityManager);

    /// @notice Sets the address of the liquidity management contract
    /// @param _liquidityManager Address of the liquidity management contract
    function setLiquidityContract(
        address _liquidityManager
    ) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        liquidityManager = _liquidityManager;
        emit LiquidityContractUpdated(_liquidityManager);
    }

    /// @notice Event emitted when the reward contract is updated.
    event RewardContractUpdated(address indexed newRewardContract);

    /// @notice Sets the address of the reward contract
    /// @param _rewardContractAddress Address of the reward contract
    function setRewardContract(
        address _rewardContractAddress
    ) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        communityPoolAddress = _rewardContractAddress;
        emit RewardContractUpdated(_rewardContractAddress);
    }

    /// @notice Event emitted when the pair address is updated.
    event PairAddressUpdated(address indexed newPairAddress);

    /// @notice Sets the address of the pair contract
    /// @param _pairAddress Address of the pair contract
    function setPairAddress(address _pairAddress) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        pairAddress = _pairAddress;
        emit PairAddressUpdated(_pairAddress);
    }

    /// @notice Burns a specified amount of tokens
    /// @param burnAmount Amount of tokens to burn
    function burnTokens(uint256 burnAmount) external nonReentrant {
        // Ensure that the caller has enough balance to burn
        uint256 balance = balanceOf(msg.sender);
        if (balance < burnAmount) {
            revert InsufficientBalance(balance, burnAmount);
        }

        // Burn the tokens
        _burn(msg.sender, burnAmount);
    }

    /// @notice Event emitted when a transfer is updated.
    event TransferUpdated(
        address indexed from,
        address indexed to,
        uint256 value
    );

    /// @notice Overrides ERC20 and ERC20Pausable's _update function to add custom transfer logic and manage liquidity
    /// @param from Address from which the tokens are transferred
    /// @param to Address to which the tokens are transferred
    /// @param value Amount of tokens to transfer
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        if (!_isDeploying) {
            // Bypass fees and limits only for liquidity addition by the Liquidity Manager
            if (from == liquidityManager && to == pairAddress) {
                super._update(from, to, value);
                return; // Skip the rest of the logic as it's a liquidity addition
            }

            // Calculate the transfer limit
            uint256 transferLimit = _settings[GovernanceSetting.TransferLimit];
            uint256 maxTransferAmount = (totalSupply() * transferLimit) / 10000;
            if (value > maxTransferAmount) {
                revert TransferExceedsGlobalLimit(value, maxTransferAmount);
            }
            // Check if 'to' address is the pair address for a sell transaction
            if (to == pairAddress) {
                manageLiquidity(from, to, value);
            }
        }

        // Regular transfer logic
        super._update(from, to, value);
        emit TransferUpdated(from, to, value);
    }

    /// @notice Manages liquidity for sell transactions
    /// @param from Address from which the tokens are being sold
    /// @param to Address to which the tokens are being transferred
    /// @param value Amount of tokens being sold
    function manageLiquidity(address from, address to, uint256 value) private {
        // Check if the transaction is with the community pair
        if (to != pairAddress) {
            revert NotSellTransactionWithCommunityPair();
        }

        // Verify initial liquidity status
        if (
            !ILiquidityManagedToken(liquidityManager)
                .getInitialLiquidityStatus()
        ) {
            revert InitialLiquidityNotProvided();
        }

        // Cooldown check
        {
            uint256 requiredBlock = lastSellBlock[from] +
                _settings[GovernanceSetting.CooldownMinBlock];
            if (block.number < requiredBlock) {
                revert CooldownPeriodNotPassed(block.number, requiredBlock);
            }

            // Update the last sell block
            lastSellBlock[from] = block.number;
        }

        // Swap limit check
        {
            uint256 swapLimitWithDecimals = _settings[
                GovernanceSetting.SwapLimit
            ] * (10 ** decimals());
            if (value > swapLimitWithDecimals) {
                revert TransferExceedsSwapLimit(value, swapLimitWithDecimals);
            }
        }

        // Fee calculations
        {
            uint256 liquidityFee = _settings[GovernanceSetting.LiquidityFee];
            uint256 burnFee = _settings[GovernanceSetting.BurnFee];

            uint256 burnAmount = (value * burnFee) / 10000;
            uint256 feeAmount = (value * liquidityFee) / 10000;

            // Burn the tokens for the burn fee
            if (burnAmount > 0) {
                _burn(from, burnAmount);
            }

            // Transfer the liquidity fee to the liquidity manager
            if (feeAmount > 0) {
                accumulatedLiquidityFees += feeAmount;
                _transfer(from, liquidityManager, feeAmount);
            }
        }

        // Liquidity management
        {
            uint256 liquidityThreshold = _settings[
                GovernanceSetting.LiquidityThreshold
            ] * (10 ** decimals());
            uint256 tokenBalanceInLiquidityManager = balanceOf(
                liquidityManager
            );

            if (tokenBalanceInLiquidityManager >= liquidityThreshold) {
                if (tokenBalanceInLiquidityManager >= liquidityThreshold) {
                    accumulatedLiquidityFees = 0; // Reset state before external call
                    ILiquidityManagedToken(liquidityManager)
                        .addLiquidityToUniswap(tokenBalanceInLiquidityManager); // External call
                }
            }
        }
    }

    /// @notice Event emitted when a game is whitelisted.
    event GameWhitelisted(address indexed gameAddress, string gameName);

    /// @notice Adds a game to the whitelist
    /// @param gameAddress Address of the game contract
    /// @param gameName Name of the game
    function addToGameWhitelist(
        address gameAddress,
        string memory gameName
    ) external {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerNotGovernance();
        }
        if (!gameDetails[gameAddress].isActive) {
            // Check if address is not already active
            bool isNewGame = true;
            uint256 whitelistedGamesLength = whitelistedGames.length;
            for (uint256 i; i < whitelistedGamesLength; ++i) {
                if (whitelistedGames[i] == gameAddress) {
                    isNewGame = false;
                    break;
                }
            }
            if (isNewGame) {
                whitelistedGames.push(gameAddress); // Add to the array
            }
        }
        gameDetails[gameAddress] = GameInfo({isActive: true, name: gameName});
        emit GameWhitelisted(gameAddress, gameName);
    }

    /// @notice Event emitted when a game is removed from the whitelist.
    event GameRemovedFromWhitelist(address indexed gameAddress);

    /// @notice Removes a game from the whitelist
    /// @dev Game address remains in the array, but marked as inactive
    /// @param gameAddress Address of the game contract
    function removeFromGameWhitelist(address gameAddress) external {
        if (!hasRole(CONSENSUS_ROLE, msg.sender)) {
            revert CallerNotConsensus();
        }
        gameDetails[gameAddress].isActive = false;
        emit GameRemovedFromWhitelist(gameAddress);
    }

    /// @notice Retrieves the list of whitelisted games along with their details
    /// @return Array of whitelisted game addresses and their corresponding details
    function getWhitelistedGames()
        external
        view
        returns (address[] memory, GameInfo[] memory)
    {
        uint256 whitelistedGamesLength = whitelistedGames.length;
        GameInfo[] memory gamesInfo = new GameInfo[](whitelistedGames.length);
        for (uint256 i; i < whitelistedGamesLength; ++i) {
            gamesInfo[i] = gameDetails[whitelistedGames[i]];
        }
        return (whitelistedGames, gamesInfo);
    }

    /// @notice Checks if a game is whitelisted and active
    /// @param gameAddress Address of the game contract
    /// @return Boolean indicating whether the game is active
    function isGameActive(address gameAddress) external view returns (bool) {
        return gameDetails[gameAddress].isActive;
    }

    /// @notice Event emitted when a reward is distributed.
    event RewardDistributed(
        address indexed gameDev,
        uint256 devShare,
        address indexed winner,
        uint256 winnerShare,
        uint256 communityShare
    );

    /// @notice Distributes rewards to the game developer, winner, and community
    /// @param gameDev Address of the game developer
    /// @param devFee Percentage of rewards allocated to the developer
    /// @param winner Address of the winner
    /// @param totalReward Total reward to distribute
    function distributeReward(
        address gameDev,
        uint256 devFee,
        address winner,
        uint256 totalReward
    ) external nonReentrant {
        // Required to be in whitelist and active to use this function
        if (!gameDetails[msg.sender].isActive) {
            revert GameNotActiveOrWhitelisted();
        }

        uint256 communityTax = getSettingValue(GovernanceSetting.CommunityTax);
        uint256 developerTax = getSettingValue(GovernanceSetting.DeveloperTax);

        // Ensure devFee does not exceed the maximum allowed developerTax
        if (devFee > developerTax) {
            revert DevFeeExceedsMax(devFee, developerTax);
        }

        uint256 communityShare = (totalReward * communityTax) / 10000; // tax values are in basis points
        uint256 developerShare = (totalReward * devFee) / 10000; // calculating developer share based on devFee
        uint256 winnerReward = totalReward - communityShare - developerShare;

        // Ensure the game contract has approved the token contract to handle these amounts
        if (!transferFrom(msg.sender, communityPoolAddress, communityShare)) {
            revert CommunityShareTransferFailed();
        }
        if (!transferFrom(msg.sender, gameDev, developerShare)) {
            revert DeveloperShareTransferFailed();
        }
        if (!transferFrom(msg.sender, winner, winnerReward)) {
            revert WinnerRewardTransferFailed();
        }

        emit RewardDistributed(
            gameDev,
            developerShare,
            winner,
            winnerReward,
            communityShare
        );
    }

    /// @notice Event emitted when a governance setting is updated.
    event GovernanceSettingUpdated(
        GovernanceSetting indexed key,
        uint256 value
    );

    /// @notice Updates a governance setting value
    /// @param key Identifier of the governance setting
    /// @param value New value for the governance setting
    function updateSetting(GovernanceSetting key, uint256 value) external {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revert CallerNotGovernance();
        }

        _settings[key] = value;
        emit GovernanceSettingUpdated(key, value);
    }

    /// @notice Retrieves the value of a specific governance setting
    /// @param key Identifier of the governance setting
    /// @return Value of the governance setting
    function getSettingValue(
        GovernanceSetting key
    ) public view returns (uint256) {
        return _settings[key];
    }

    /// @notice Grants consensus role to an account
    /// @param account Address of the account to grant consensus role
    function setConsensusContract(address account) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        _grantRole(CONSENSUS_ROLE, account);
    }

    /// @notice Grants governance role to an account
    /// @param account Address of the account to grant governance role
    function setGovernanceContract(address account) external nonReentrant {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerNotAdmin();
        }
        _grantRole(GOVERNANCE_ROLE, account);
    }

    /// @notice Pauses token transfers
    function pause() external {
        if (!hasRole(CONSENSUS_ROLE, msg.sender)) {
            revert CallerNotConsensus();
        }
        _pause();
    }

    /// @notice Unpauses token transfers
    function unpause() external {
        if (!hasRole(CONSENSUS_ROLE, msg.sender)) {
            revert CallerNotConsensus();
        }
        _unpause();
    }
}
