pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Presale is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    /// @notice Address of USDC
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    /// @notice The mead contract
    IERC20Upgradeable public mead;

    /// @notice The funding token
    IERC20Upgradeable public usdc;

    /// @notice A running tally of how much USDC was raised
    uint256 public total;

    /// @notice How much USDC did each person deposit
    mapping(address => uint256) deposited;

    /// @notice A list of the cooldowns for individuals who are vesting tokens
    mapping(address => uint256) cooldown;

    /// @notice The amount of unique addresses that participated
    uint256 public participants;

    /// @notice A mapping of each address and whether it is whitelisted
    mapping(address => bool) whitelist;
    
    /// @notice Maximum input array length used in `addToWhitelist`
    uint256 public constant MAX_ARRAY_LENGTH = 50;

    /// @notice Whether or not the sale is running
    bool public isRunning;

    /// @notice The total amount of USDC aiming to raise
    uint256 public raiseAim;

    /// @notice How many tokens you get for 1 USDC
    uint256 public tokenRate;

    /// @notice The minimum amount of USDC someone can deposit
    uint256 public min;

    /// @notice The maximum amount of USDC someone can deposit
    uint256 public max;

    /// @notice The time in the future past launch when tokens will be claimable 
    uint256 public unlockDate;

    /// @notice The vesting period
    uint256 public vestingPeriod;

    /// @notice The amount of USDC to vest after each period
    uint256 public vestingAmount;

    function initialize(IERC20Upgradeable _mead, IERC20Upgradeable _usdc) external initializer {
        mead = _mead;
        usdc = _usdc;
    }

    function configure(uint256 _raiseAim, uint256 _tokenRate, uint256 _min, uint256 _max, uint256 _unlockDate, uint256 _vestingPeriod, uint256 _vestingAmount) external onlyOwner {
        raiseAim = _raiseAim;
        tokenRate = _tokenRate;
        min = _min;
        max = _max;
        unlockDate = _unlockDate;
        vestingPeriod = _vestingPeriod;
        vestingAmount = _vestingAmount;
    }

    function start() external onlyOwner {
        isRunning = true;
    }

    /**
     * @notice Adds addresses to the whitelist
     */
    function addToWhitelist(address[] memory users) external onlyOwner {
        require(
            users.length <= MAX_ARRAY_LENGTH,
            "Too many addresses"
        );

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            whitelist[user] = true;
        }
    }

    function isWhitelisted(address account) external view returns(bool) {
        return whitelist[account];
    }

    /**
     * @notice Allows a user to deposit USDC 
     */
    function deposit(uint256 amount) external nonReentrant {
        require(isRunning, "Presale not running");
        require(whitelist[msg.sender], "User not whitelisted");
        require((deposited[msg.sender] + amount) <= max, "Cant deposit more than max");
        require(amount >= min, "Cant deposit less than min");
        require(amount > 0, "Amount must be above 0");

        if (deposited[msg.sender] == 0) {
            participants++;
        }
        deposited[msg.sender] += amount;
        total += amount;

        usdc.transferFrom(msg.sender, address(this), amount);

        //emit Deposit(account, amount);
    }

    /**
     * @notice Allows the owner to withdraw tokens that are currently sat/stuck in this contract
     */
    function withdraw(address _token) external onlyOwner {
        IERC20Upgradeable(_token).transfer(msg.sender, IERC20Upgradeable(_token).balanceOf(address(this)));
    }

    /**
     * @notice Lets a user claim their next batch of tokens 
     */
    function claim() external nonReentrant {
        uint256 amount = deposited[msg.sender];
        require(amount > 0, "No tokens to claim");
        require(unlockDate >= block.timestamp, "Waiting for unlock");
        require(block.timestamp >= cooldown[msg.sender], "Waiting for next vest");

        // If amount of tokens left is greater than the vesting amount, then shave off the end
        // Put the account on cooldown til the next vesting period is up
        if (amount > vestingAmount) {
            amount = vestingAmount;
            cooldown[msg.sender] = block.timestamp + vestingPeriod;
        }

        deposited[msg.sender] -= amount;

        // Divide by 6 to get the decimal value of deposited tokens
        uint256 tokens = (amount / 6) * tokenRate;
        mead.transferFrom(address(this), msg.sender, tokens);
    }
}