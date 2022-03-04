pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../ERC-20/xMead.sol";
import "../ERC-721/Brewery.sol";
import "../TavernSettings.sol";
import "./WhitelistPresale.sol";

contract Premint is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    /// @notice The brewery contracts
    Brewery public brewery;

    /// @notice The xmead contract
    XMead public xmead;

    /// @notice The funding token
    ERC20Upgradeable public usdc;

    /// @notice The whitelisted presale
    WhitelistPresale whitelistPresale;

    /// @notice How much USDC did each person deposit
    mapping(address => uint256) deposited;

    /// @notice The amount of unique addresses that participated
    uint256 public participants;

    /// @notice Whether or not the sale is running
    bool public isRunning;

    /// @notice A running tally of how much USDC was raised
    uint256 public totalDeposited;

    /// @notice The time that the sale was started
    uint256 public startTime;

    struct Batch {
        uint256 supply;
        uint256 minted;
        uint256 price;
    }

    /// @notice The list of batches of BREWERYs for the publci premint
    /// @dev The order matters, and batches will be released in index order
    Batch[] public batches;

    /// @notice The current public batch that is active
    uint256 public currentBatchIndex;

    /// @notice The batch dedicated to whitelist people only
    Batch whitelistBatch;

    /// @notice The limit that each whitelisted wallet is allowed to purchase off of the allocated whitelist portion
    uint256 public whitelistLimit;

    /// @notice The amounts of BREWERYs that each whitelisted user has picked up
    mapping(address => uint256) whitelistAmounts;

    event PremintStarted(bool enabled, uint256 time);
    event Mint(address investor, uint256 breweryCount, uint256 usdcCost);

    function initialize(address _brewery, address _xmead, address _usdc, address _whitelistPresale) external initializer {
        __Context_init();
        __Ownable_init();

        brewery = Brewery(_brewery);
        xmead = XMead(_xmead);
        usdc = ERC20Upgradeable(_usdc);
        whitelistPresale = WhitelistPresale(_whitelistPresale);
    }

    /**
     * @notice Adds a batch of BREWERYs
     */
    function addBatch(uint256 supply, uint256 price) external onlyOwner {
        Batch memory batch = Batch({
            supply: supply,
            price: price,
            minted: 0
        });
        
        batches.push(batch);
    }

    /**
     * @notice Clear the batch list (not used unless input error data)
     */
    function clearBatches() external onlyOwner {
        currentBatchIndex = 0;
        delete batches;
    }

    /**
     * @notice Sets the whitelist batch
     */
    function setWhitelistBatch(uint256 supply, uint256 limit) external onlyOwner {
        whitelistBatch = Batch({
            supply: supply,
            price: 0,
            minted: 0
        });
        whitelistLimit = limit;
    }

    /**
     * @notice Starts the presale
     */
    function start() external onlyOwner {
        startTime = block.timestamp;
        isRunning = true;
        emit PremintStarted(true, block.timestamp);
    }
    
    /**
     * @notice Ends the presale
     */
    function end() external onlyOwner {
        require(isRunning, "Sale isn't running");
        isRunning = false;
    }

    /**
     * @notice Get the current batch amount
     */
    function getBatchAmount() external view returns (uint256) {
        return batches[currentBatchIndex].supply;
    }

    /**
     * @notice Get the minted on the current batch
     */
    function getMinted() external view returns (uint256) {
        return batches[currentBatchIndex].minted;
    }

    /**
     * @notice Get the price of the current batch 
     */
    function getCurrentPrice() external view returns (uint256) {
        return batches[currentBatchIndex].price;
    }

    /**
     * @notice Handles the minting of actual BREWERYs
     */
    function _mint(uint256 amount) internal {
        // Do the minting
        for(uint256 i = 0; i < amount; ++i) {
            brewery.mint(msg.sender, "");
        }
    }

    /**
     * @notice Updates the batches
     */
    function _updateBatches(uint256 amount) internal {
        if (_isNextBatch() && _isSpillover(amount)) {
            batches[currentBatchIndex].minted = batches[currentBatchIndex].supply;
            batches[currentBatchIndex + 1].minted += _getSpillover(amount);
            currentBatchIndex++;
        } else {
            batches[currentBatchIndex].minted += amount;
        }
    }

    /**
     * @notice Updates the deposited and participant varaibles for the front end
     */
    function _updateGlobals(uint256 price) internal {
        if (deposited[msg.sender] == 0) {
            participants++;
        }
        deposited[msg.sender] += price;
        totalDeposited += price;
    }

    /**
     * @return Whether or not there is a next batch in queue
     */
    function _isNextBatch() public view returns (bool) {
        return currentBatchIndex < batches.length - 1;
    }

    /**
     * @return Whether or not there will be a spillover into the next batch
     */
    function _isSpillover(uint256 amount) public view returns (bool) {
        return batches[currentBatchIndex].minted + amount > batches[currentBatchIndex].supply;
    }

    /**
     * @return The spillover amount to be put onto the next batch
     */
    function _getSpillover(uint256 amount) public view returns (uint256) {
        return amount - (batches[currentBatchIndex].supply - batches[currentBatchIndex].minted);
    }

    function _getNextSupply() public view returns (uint256) {
        if (_isNextBatch()) {
            return batches[currentBatchIndex + 1].supply;
        } else {
            return 0;
        }
    }

    function _getNextPrice() public view returns (uint256) {
        if (_isNextBatch()) {
            return batches[currentBatchIndex + 1].price;
        } else {
            return 0;
        }
    }

    /**
     * @notice Returns the full price to pay for a certain amount of brewery, calculating for spillover
     */
    function getPrice(uint256 amount) public view returns (uint256) {
        uint256 price = batches[currentBatchIndex].price * amount;

        // If there is a next batch, and there could be a spill over, then calculate the new price for the total amount of BREWERYs
        uint256 spill = 0;
        if (_isNextBatch()) {
            if (_isSpillover(amount)) {
                spill = _getSpillover(amount);
                price = batches[currentBatchIndex].price * (amount - spill) + batches[currentBatchIndex + 1].price * spill;
            }
        }

        return price;
    }

    /**
     * @notice Allows a user to deposit USDC in exchange for BREWERYs
     */
    function mint(uint256 amount) external nonReentrant {
        TavernSettings settings = TavernSettings(brewery.settings());
        require(isRunning, "Presale not running");
        require(amount > 0, "Amount must be above 0");
        require(amount <= settings.txLimit(), "Amount above tx limit");
        require(brewery.balanceOf(msg.sender) + amount <= settings.walletLimit(), "Amount above wallet limit");

        // If there isn't a next batch (i.e. we are on the last batch), then make sure the user isn't going to hit the limit
        if(!_isNextBatch()) {
            // Otherwise revert if we are at the end
            require(!_isSpillover(amount), "Reached end of supply");
        }

        // Calculate the price
        uint256 price = getPrice(amount);

        // Transfer the USDC
        usdc.transferFrom(msg.sender, address(this), price);

        // Update batches
        _updateBatches(amount);

        // Sort the global variables
        _updateGlobals(price);

        // Mint the BREWERYs
        _mint(amount);

        emit Mint(msg.sender, amount, price);
    }

    /**
     * @notice Allows a user to deposit XMead in exchange for BREWERYs
     */
    function mintWithXMead(uint256 amount) external nonReentrant {
        TavernSettings settings = TavernSettings(brewery.settings());
        require(isRunning, "Presale not running");
        require(amount > 0, "Amount must be above 0");
        require(amount <= settings.txLimit(), "Amount above tx limit");
        require(brewery.balanceOf(msg.sender) + amount <= settings.walletLimit(), "Amount above wallet limit");

        // Revert the batches if there is a spill over
        bool isNextBatch = currentBatchIndex < batches.length - 1 && batches[currentBatchIndex].minted + amount > batches[currentBatchIndex].supply;
        if (!isNextBatch) {
            require(batches[currentBatchIndex].minted + amount <= batches[currentBatchIndex].supply, "Reached end of supply");
        }
        
        // Calculate price and redeem the users xMEAD
        uint256 price = settings.xMeadCost() * amount;
        xmead.redeem(msg.sender, price);

        // Update batches
        _updateBatches(amount);

        // Mint the BREWERYs
        _mint(amount);

        emit Mint(msg.sender, amount, price);
    }

    /**
     * @notice Allows a whitelisted user to deposit XMead in exchange for exclusive whitelisted BREWERYs
     */
    function whitelistMintWithXMead(uint256 amount) external nonReentrant {
        TavernSettings settings = TavernSettings(brewery.settings());
        require(isRunning, "Presale not running");
        require(amount > 0, "Amount must be above 0");
        require(amount <= settings.txLimit(), "Amount above tx limit");
        require(brewery.balanceOf(msg.sender) + amount <= settings.walletLimit(), "Amount above wallet limit");
        require(whitelistPresale.isWhitelisted(msg.sender), "User wasnt whitelisted");
        require(whitelistAmounts[msg.sender] + amount <= whitelistLimit, "Whitelisted user cant go above limits");

        // Revert the batches if there is a spill over
        bool isNextBatch = currentBatchIndex < batches.length - 1 && whitelistBatch.minted + amount > whitelistBatch.supply;
        if (!isNextBatch) {
            require(whitelistBatch.minted + amount <= whitelistBatch.supply, "Reached end of supply");
        }
        
        // Calculate price and redeem the users xMEAD
        uint256 price = settings.xMeadCost() * amount;
        xmead.redeem(msg.sender, price);

        // Mint the BREWERYs
        _mint(amount);

        emit Mint(msg.sender, amount, price);
    }

    /**
     * @notice Allows the owner to withdraw tokens that are currently sat/stuck in this contract
     */
    function withdraw(address _token) external onlyOwner {
        IERC20Upgradeable(_token).transfer(msg.sender, IERC20Upgradeable(_token).balanceOf(address(this)));
    }
}