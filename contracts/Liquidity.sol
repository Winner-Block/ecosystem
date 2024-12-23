// SPDX-License-Identifier: GPL-3.0
/// @notice Contract managing liquidity
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IWBlockToken} from "./interfaces/IWBlockToken.sol";
import {ILiquidityErrors} from "./utils/ILiquidityErrors.sol";

/**
 * @title WinnerBlock LiquidityManagedToken Contract
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
contract LiquidityManagedToken is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ILiquidityErrors
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Storage gap for upgradeable contract
    uint256[50] private __gap;

    /// @notice Uniswap V2 Router contract address
    IUniswapV2Router02 public uniswapRouter;

    /// @notice Address of the Uniswap community LP pair contract for this token
    address public uniswapPair;

    /// @notice Token contract address
    IWBlockToken public WBlockToken;

    /// @notice Consensus contract address
    bytes32 public constant CONSENSUS_ROLE = keccak256("CONSENSUS_ROLE");

    /// @notice Accumulated Liquidity fees on sell swaps
    uint256 public accumulatedLiquidityFees;

    /// @notice For public Information purpose
    bool public initialLiquidityAdded;

    /// @notice For public Information purpose
    address public tokenContractAddress;

    mapping(address seller => uint256 lastBlockSold) private lastSellBlock;

    /// @notice Emitted when the contract is initialized with token and Uniswap router addresses
    event Initialized(
        address indexed tokenAddress,
        address indexed uniswapRouterAddress
    );

    /// @notice Initializes the contract and sets up its parameters
    /// @dev This function sets the token address, Uniswap router address, and initializes other settings
    /// It also grants the admin role to the caller and configures initial settings for liquidity
    /// @param _tokenAddress The address of the Ecosystem Token contract
    /// @param _uniswapRouterContract The address of the Uniswap V2 Router contract
    function initialize(
        address _tokenAddress,
        address _uniswapRouterContract
    ) external initializer {
        if (_tokenAddress == address(0)) {
            revert InvalidTokenAddress();
        }

        __ReentrancyGuard_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        initialLiquidityAdded = false;

        tokenContractAddress = _tokenAddress;
        WBlockToken = IWBlockToken(_tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setRouterAddress(_uniswapRouterContract);

        emit Initialized(_tokenAddress, _uniswapRouterContract);
    }

    /// @notice Authorize upgrade function for UUPSUpgradeable
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Emitted when Ether is received by the contract
    event EtherReceived(address indexed sender, uint256 amount);

    /// @notice Receive function to accept incoming ETH transactions
    receive() external payable {
        // Logic to handle received Ether, e.g., updating state or emitting event
        emit EtherReceived(msg.sender, msg.value);
    }

    function getTokenContract() private view returns (IWBlockToken) {
        return IWBlockToken(address(WBlockToken));
    }

    /// @notice Get Uniswap Router address
    /// @return Address of Uniswap Router
    function getUniswapRouterAddress() external view returns (address) {
        return address(uniswapRouter);
    }

    /// @notice Get initial liquidity status
    /// @return Initial liquidity status
    function getInitialLiquidityStatus() external view returns (bool) {
        return initialLiquidityAdded;
    }

    /// @notice Set consensus contract
    /// @param account Address of the consensus contract
    function setConsensusContract(address account) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _grantRole(CONSENSUS_ROLE, account);
    }

    /// @notice Emitted when the router address is changed
    event RouterAddressChanged(
        address indexed newRouter,
        address indexed newPair
    );

    /// @notice Set router address
    /// @param _router Uniswap Router contract address
    function setRouterAddress(address _router) private {
        if (_router == address(0)) {
            revert InvalidUniswapRouterAddress();
        }
        uniswapRouter = IUniswapV2Router02(_router);

        // Create the Uniswap pair
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(WBlockToken),
            uniswapRouter.WETH()
        );

        emit RouterAddressChanged(_router, uniswapPair);
    }

    /// @notice Emitted to confirm liquidity addition to router
    event LiquidityAdditionSuccessful(
        uint256 requestedTokenAmount,
        uint256 requestedEthAmount,
        uint256 actualTokenAmount,
        uint256 actualEthAmount,
        uint256 liquidityTokens,
        address indexed initiator
    );

    /// @notice Add initial liquidity
    /// @param tokenAmount Amount of token to add as liquidity
    /// @param ethAmount Amount of ETH to add as liquidity
    function addInitialLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount
    ) private {
        // Ensure uniswapRouter is valid
        if (address(uniswapRouter) == address(0)) {
            revert UniswapRouterNotSet();
        }

        // Approve token transfer to Uniswap router
        if (!WBlockToken.approve(address(uniswapRouter), tokenAmount)) {
            revert ApprovalFailed();
        }

        // Add liquidity to Uniswap
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter
            .addLiquidityETH{value: ethAmount}(
            address(WBlockToken),
            tokenAmount,
            0, // Minimum amount of tokens to add
            0, // Minimum amount of ETH to add
            address(this), // Liquidity tokens are sent to this contract
            block.timestamp + 300 // Deadline
        );

        emit LiquidityAdditionSuccessful(
            tokenAmount,
            ethAmount,
            amountToken,
            amountETH,
            liquidity,
            msg.sender
        );
    }

    /// @notice Emitted when initial liquidity is added
    event InitialLiquidityAdded(
        uint256 tokenAmount,
        uint256 ethAmount,
        address indexed initiator
    );

    /// @notice Function to start adding liquidity when minimum reached
    function initialLiquidity() external nonReentrant {
        if (!hasRole(CONSENSUS_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        if (initialLiquidityAdded) {
            revert InitialLiquidityAlreadyAdded();
        }

        uint256 tokenBalance = WBlockToken.balanceOf(address(this));
        uint256 ethBalance = address(this).balance;

        // Define the required amounts for tokens and ETH
        uint256 requiredTokenAmount = 2_180_486_321 *
            (10 ** WBlockToken.decimals());
        uint256 requiredEthAmount = 26.44 ether;

        if (tokenBalance < requiredTokenAmount) {
            revert InsufficientTokenBalance(tokenBalance, requiredTokenAmount);
        }
        if (ethBalance < requiredEthAmount) {
            revert InsufficientEthBalance(ethBalance, requiredEthAmount);
        }

        initialLiquidityAdded = true;

        // Add initial liquidity
        addInitialLiquidity(requiredTokenAmount, requiredEthAmount);

        emit InitialLiquidityAdded(
            requiredTokenAmount,
            requiredEthAmount,
            msg.sender
        );
    }

    /// @notice Calculate optimal ETH amount for liquidity
    /// @param tokenAmount Amount of token
    /// @return Optimal ETH amount
    function calculateOptimalEthAmount(
        uint256 tokenAmount
    ) private view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(uniswapPair)
            .getReserves();

        uint256 tokenReserve;
        uint256 ethReserve;

        // Check which reserve is ETH and which is the token
        // Compare the address of the WBlockToken contract with the address returned by token0()
        if (address(WBlockToken) == IUniswapV2Pair(uniswapPair).token0()) {
            tokenReserve = reserve0;
            ethReserve = reserve1;
        } else {
            tokenReserve = reserve1;
            ethReserve = reserve0;
        }

        // Calculate the amount of ETH based on the pool's token-to-ETH ratio
        if (tokenReserve > 0 && ethReserve > 0) {
            return (tokenAmount * ethReserve) / tokenReserve;
        } else {
            return 0; // Return 0 if the reserves are not set
        }
    }

    // Define a buffer percentage
    uint256 internal constant BUFFER_PERCENTAGE = 95;

    /// @notice Emitted when liquidity is added to Uniswap
    event LiquidityAdded(
        uint256 tokenAmount,
        uint256 ethAmount,
        address indexed initiator
    );

    /// @notice Add liquidity to Uniswap when token threshold meets
    /// @param tokenAmount Amount of token
    function addLiquidityToUniswap(uint256 tokenAmount) external {
        IWBlockToken tokenContract = getTokenContract();
        if (msg.sender != address(tokenContract)) {
            revert CallerNotTokenContract();
        }
        if (!initialLiquidityAdded) {
            revert InitialLiquidityNotProvided();
        }

        uint256 contractTokenBalance = WBlockToken.balanceOf(address(this));
        if (tokenAmount > contractTokenBalance) {
            revert InsufficientContractTokenBalance(
                contractTokenBalance,
                tokenAmount
            );
        }

        // Split the token amount for swapping and adding to liquidity
        uint256 tokensToSwap = tokenAmount / 2;
        uint256 tokensToAdd = tokenAmount - tokensToSwap;

        // Swap half of the tokens for ETH and get the actual amount of ETH received
        uint256 ethReceived = swapTokensForEth(tokensToSwap);

        /* // Update tokensToAdd to reflect the current balance after the swap
        uint256 updatedTokenBalance = WBlockToken.balanceOf(address(this));
        tokensToAdd = updatedTokenBalance > tokensToAdd
            ? tokensToAdd
            : updatedTokenBalance; */

        uint256 ethAmountNeeded = calculateOptimalEthAmount(tokensToAdd);

        // Apply the buffer to the ETH amount needed
        uint256 ethAmountWithBuffer = (ethAmountNeeded * BUFFER_PERCENTAGE) /
            100;

        // Use the lesser of the eth received and the buffered eth amount
        uint256 ethAmountToUse = ethReceived < ethAmountWithBuffer
            ? ethReceived
            : ethAmountWithBuffer;

        // Then use ethAmountToUse in the addLiquidity function
        addLiquidity(tokensToAdd, ethAmountToUse);

        emit LiquidityAdded(tokensToAdd, ethAmountToUse, msg.sender);

        // Utilize remaining ETH for additional liquidity
        utilizeRemainingEthForLiquidity();
    }

    /// @notice Emitted when tokens are swapped for auto LP
    event TokensSwapped(
        uint256 indexed tokenAmount,
        uint256 indexed requestedEthAmount,
        uint256 indexed actualEthReceived
    );

    /// @notice Swap tokens for ETH
    /// @param tokenAmount Amount of token to swap
    /// @return Amount of ETH received
    function swapTokensForEth(uint256 tokenAmount) private returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(WBlockToken);
        path[1] = uniswapRouter.WETH();

        if (!WBlockToken.approve(address(uniswapRouter), tokenAmount)) {
            revert ApprovalFailed();
        }

        // Store the contract's current ETH balance
        uint256 initialBalance = address(this).balance;

        // Execute swap and capture the actual ETH amount received
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        uint256 actualEthReceived = amounts[1]; // Assuming path[1] is ETH

        // Calculate the amount of ETH received from the swap
        uint256 ethReceived = address(this).balance - initialBalance;

        emit TokensSwapped(tokenAmount, ethReceived, actualEthReceived);

        return ethReceived;
    }

    /// @notice Emitted when auto liquidity is added in pool
    event AutoLiquidityAdded(
        uint256 requestedTokenAmount,
        uint256 requestedEthAmount,
        uint256 actualTokenAmount,
        uint256 actualEthAmount,
        uint256 liquidityTokens,
        address indexed initiator
    );

    /// @notice Add liquidity to Uniswap
    /// @param tokenAmount Amount of token to add as liquidity
    /// @param ethAmount Amount of ETH to add as liquidity
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        if (address(uniswapRouter) == address(0)) {
            revert UniswapRouterNotSet();
        }

        if (!WBlockToken.approve(address(uniswapRouter), tokenAmount)) {
            revert ApprovalFailed();
        }

        // Add the liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter
            .addLiquidityETH{value: ethAmount}(
            address(WBlockToken),
            tokenAmount,
            0, // Minimum amount of tokens to add
            0, // Minimum amount of ETH to add
            address(this),
            block.timestamp
        );

        // Emitting with captured values
        emit AutoLiquidityAdded(
            tokenAmount,
            ethAmount,
            amountToken,
            amountETH,
            liquidity,
            msg.sender
        );
    }

    /// @notice Utilize remaining ETH for liquidity
    function utilizeRemainingEthForLiquidity() private {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            // Use half of the remaining ETH to buy tokens
            uint256 ethToUse = ethBalance / 2;

            // Buy tokens with ETH
            uint256 tokensBought = swapEthForTokens(ethToUse);

            // Add liquidity with the newly bought tokens and the corresponding ETH
            addLiquidity(tokensBought, ethToUse);
        }
    }

    /// @notice Emitted when token are swapped for LP addition
    event TokensSwappedForEth(
        uint256 indexed ethSpent,
        uint256 indexed requestedTokensReceived,
        uint256 indexed actualTokensReceived
    );

    /// @notice Swap ETH for tokens
    /// @param ethAmount Amount of ETH to swap
    /// @return Amount of tokens received
    function swapEthForTokens(uint256 ethAmount) private returns (uint256) {
        if (address(uniswapRouter) == address(0)) {
            revert UniswapRouterNotSet();
        }

        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(WBlockToken);

        uint256 initialTokenBalance = WBlockToken.balanceOf(address(this));

        // Make the swap
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{
            value: ethAmount
        }(
            0, // Accept any amount of Tokens
            path,
            address(this),
            block.timestamp
        );

        uint256 actualTokensReceived = amounts[1]; // Assuming path[1] is the token

        uint256 tokensReceived = WBlockToken.balanceOf(address(this)) -
            initialTokenBalance;

        // Emitting with captured values
        emit TokensSwappedForEth(
            ethAmount,
            tokensReceived,
            actualTokensReceived
        );

        return tokensReceived;
    }
}
