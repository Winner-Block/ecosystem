// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address recipient, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IWBlockToken is IERC20 {
    function distributeReward(
        address gameDev,
        uint256 devFee,
        address winner,
        uint256 totalReward
    ) external;
}

contract WinGame {
    IWBlockToken public token;
    uint256 public constant TOKEN_COST = 1000000 * (10 ** 9);
    uint256 public constant TOKEN_RETURN = 1000000 * (10 ** 9);
    address public constant devAddress =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 public devTax; // Make devTax a state variable
    uint256 public initialDevTax = 1;

    // Modifier to restrict access to devAddress
    modifier onlyDev() {
        require(
            msg.sender == devAddress,
            "Not authorized: Only devAddress can call this function"
        );
        _;
    }

    // Constructor to initialize token and devTax
    constructor(address tokenAddress) {
        token = IWBlockToken(tokenAddress);
        devTax = initialDevTax;
    }

    // Receive function to accept incoming ETH transactions
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value); // Emit event when Ether is received
    }

    // Event for logging received Ether
    event EtherReceived(address sender, uint256 amount);

    // Function to exchange tokens
    function exchangeTokens() public {
        // Transfer TOKEN_COST from msg.sender to this contract
        require(
            token.transferFrom(msg.sender, address(this), TOKEN_COST),
            "Transfer failed"
        );

        // Approve TOKEN_RETURN from this contract to the token contract
        require(
            token.approve(address(this), TOKEN_RETURN),
            "approve to token contract failed"
        );

        // Call distributeReward in the token contract
        token.distributeReward(devAddress, devTax, msg.sender, TOKEN_RETURN);
    }

    // Function to set the devTax dynamically (only callable by devAddress)
    function setDevTax(uint256 newDevTax) public onlyDev {
        require(newDevTax > 0, "Dev tax must be greater than 0");
        devTax = newDevTax;
    }
}
