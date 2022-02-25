pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../ERC-20/xMead.sol";

contract PublicPresale is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    /// @notice The xmead contract
    XMead public xmead;

    /// @notice The funding token
    ERC20Upgradeable public usdc;

    /// @notice How much USDC did each person deposit
    mapping(address => uint256) deposited;

    /// @notice The amount of unique addresses that participated
    uint256 public participants;

    /// @notice Whether or not the sale is running
    bool public isRunning;

    /// @notice The total amount of USDC aiming to raise
    uint256 public raiseAim;

    /// @notice A running tally of how much USDC was raised
    uint256 public totalDeposited;

    /// @notice How many tokens you get for 1 USDC
    uint256 public tokenRate;

    /// @notice The minimum amount of USDC someone can invest
    uint256 public min;

    /// @notice The list of the maximum amounts of USDC that someone can invest
    uint256[] public maxContributions;

    /// @notice The time interval before we increase to the next possible max cap
    uint256 public timeInterval;

    /// @notice The time that the sale was started
    uint256 public startTime;

    event PresaleStarted(bool enabled, uint256 time);
    event Deposit(address investor, uint256 amount);

    function initialize(address _xmead, address _usdc) external initializer {
        __Context_init();
        __Ownable_init();

        xmead = XMead(_xmead);
        usdc = ERC20Upgradeable(_usdc);
    }

    function configure(
        uint256 _raiseAim, 
        uint256 _tokenRate, 
        uint256 _min,
        uint256 _max,
        uint256 _intervals,
        uint256 _timeInterval
    ) external onlyOwner {
        raiseAim = _raiseAim;
        tokenRate = _tokenRate;
        min = _min;
        timeInterval = _timeInterval;

        // Set up the maximum contributions
        for (uint i = 0; i < _intervals; ++i) {
            maxContributions.push(_max * (i + 1));
        }
    }
    
    /**
     * @notice Starts the presale
     */
    function start() external onlyOwner {
        startTime = block.timestamp;
        isRunning = true;
        emit PresaleStarted(true, block.timestamp);
    }

    /**
     * @notice Returns the interval that we are in based on the `interval` variable
     */
    function getInterval() public view returns (uint256) {
        if (isRunning && block.timestamp > startTime) {
            return (block.timestamp - startTime) / timeInterval;
        } else {
            return 0;
        }
    }

    /**
     * @notice Calculates the maximum contribution amount based on the `interval` and the decimal count of the invest token
     */
    function getMaxContribution() public view returns (uint256) {
        require(maxContributions.length > 0, "Max contributions not set");
        uint256 i = getInterval();
        if (i >= maxContributions.length) {
            return maxContributions[maxContributions.length - 1];
        } else {
            return maxContributions[i];
        }
    }

    /**
     * @notice Allows a user to deposit USDC 
     */
    function invest(uint256 amount) external nonReentrant {
        require(isRunning, "Presale not running");
        require(totalDeposited + amount <= raiseAim, "Exceeded raise aim");
        uint256 max = getMaxContribution();
        require(deposited[msg.sender] + amount <= max, "Cant deposit more than max");
        require(amount >= min, "Cant deposit less than min");
        require(amount > 0, "Amount must be above 0");

        if (deposited[msg.sender] == 0) {
            participants++;
        }
        deposited[msg.sender] += amount;
        totalDeposited += amount;

        // Issue is equal to the amount of USDC deposited * the amount of xMEAD for each 1 USDC
        uint256 issueAmount = (amount * tokenRate) / (10**usdc.decimals());

        // Take USDC
        usdc.transferFrom(msg.sender, address(this), amount);

        // Issue xMEAD
        xmead.issue(msg.sender, issueAmount);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Allows the owner to withdraw tokens that are currently sat/stuck in this contract
     */
    function withdraw(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
}