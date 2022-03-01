pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Renovation.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is Initializable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice A descriptive name for a collection of NFTs in this contract
    string private constant NAME = "Brewery";

    /// @notice An abbreviated name for NFTs in this contract
    string private constant SYMBOL = "BREWERY";

    /// @notice Address of USDC
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    /// @notice Used to give extra precision for percentages
    uint256 public constant PRECISION = 1e10;

    /// @notice The contract address of the MEAD token
    IERC20Upgradeable public meadToken;

    /// @notice The wallet address of the governing treasury
    address public tavernsKeep;

    /// @notice The wallet address of the rewards pool
    address public rewardsPool;

    /// @notice The address for the renovation
    address public renovationAddress;

    struct BreweryStats {
        string name;                           // A unique string
        uint256 xp;                            // A XP value, increased on each claim
        uint256 productionRatePerSecondMultiplier;      // The percentage increase to base yield
        uint256 fermentationPeriodMultiplier;  // The percentage decrease to the fermentation period
        uint256 experienceMultiplier;          // The percentage increase to experience gain
        uint256 totalYield;                    // The total yield this brewery has produced
        uint256 lastTimeClaimed;               // The last time this brewery has had a claim
    }

    /// @notice Whether or not the USDC payments have been enabled (based on the treasury)
    bool public isUSDCEnabled;

    /// @notice The base amount of daily MEAD that each Brewery earns
    uint256 public baseProductionRatePerSecond;

    /// @notice The base fermentation period in seconds
    uint256 public baseFermentationPeriod;

    /// @notice The base experience amount awarded for each second past the fermentation period
    uint256 public baseExperiencePerSecond;

    /// @notice A mapping of token ID to brewery stats
    mapping (uint256 => BreweryStats) public breweryStats;

    /// @notice A list of tiers (index) and XP values (value), tiers.length = max tier.
    uint256[] public tiers;

    /// @notice A list of tiers (index) and yield bonuses (value), tiers.length = max tier
    uint256[] public yields;

    function initialize(
        address _meadTokenAddress,
        address _tavernsKeep,
        address _rewardsPool,
        address _renovationAddress,
        uint256 _baseDailyYield,
        uint256 _baseFermentationPeriod
    ) external initializer {
        __ERC721_init(NAME, SYMBOL);
        __ERC721Enumerable_init();
        __Ownable_init();

        tavernsKeep = _tavernsKeep;
        rewardsPool = _rewardsPool;
        renovationAddress = _renovationAddress;
        meadToken = IERC20Upgradeable(_meadTokenAddress);

        baseFermentationPeriod = _baseFermentationPeriod;
        baseProductionRatePerSecond = _baseDailyYield / 86400;
    }

    function setBaseProductionRatePerSecond(uint256 _baseProductionRatePerSecond) external onlyOwner {
        baseProductionRatePerSecond = _baseProductionRatePerSecond;
    }

    function setBaseFermentationPeriod(uint256 _baseFermentationPeriod) external onlyOwner {
        baseFermentationPeriod = _baseFermentationPeriod;
    }

    function setBaseExperiencePerSecond(uint256 _baseExperiencePerSecond) external onlyOwner {
        baseExperiencePerSecond = _baseExperiencePerSecond;
    }

    function getProductionRatePerSecond(uint256 _tokenId) public view returns(uint256) {
        return baseProductionRatePerSecond * breweryStats[_tokenId].productionRatePerSecondMultiplier / (100 * PRECISION);
    }

    function getFermentationPeriod(uint256 _tokenId) public view returns(uint256) {
        return baseFermentationPeriod * breweryStats[_tokenId].fermentationPeriodMultiplier / (100 * PRECISION);
    }

    function getExperiencePerSecond(uint256 _tokenId) public view returns(uint256) {
        return baseExperiencePerSecond * breweryStats[_tokenId].experienceMultiplier / (100 * PRECISION);
    }

    /**
     * @notice Adds a tier and it's associated with XP value
     */
    function addTier(uint256 _xp, uint256 _yield) external onlyOwner {
         tiers.push(_xp);
         yields.push(_yield);
    }

    /**
     * @notice Edits the XP value of a particular tier
     */
    function editTier(uint256 _tier, uint256 _xp, uint256 _yield) external onlyOwner {
        require(tiers.length >= _tier, "Tier doesnt exist");
        tiers[_tier - 1] = _xp;
        yields[_tier - 1] = _yield;
    }

    /**
     * @notice Clears the tiers array
     * @dev Should only be used if wrong tiers were added
     */
    function clearTiers() external onlyOwner {
        delete tiers;
        delete yields;
    }

    /**
     * @notice Calculates the tier of a particular token ID
     */
    function getTier(uint256 _tokenId) public view returns(uint256) {
        // Tier 1: 0   - 99
        // Tier 2: 100 - 249
        // Tier 3: 250+
        uint256 xp = breweryStats[_tokenId].xp;
        for(uint i = 0; i < tiers.length; ++i) {
            if (xp > tiers[i]) {
                continue;
            }
            return i + 1;
        }
        return 0;
    }

    /**
     * @notice 
     */
    function getYield(uint256 _tokenId) public view returns(uint256) {
        return yields[getTier(_tokenId) - 1];
    }

    /**
     * @notice 
     */
    function getYieldFromTier(uint256 _tier) public view returns(uint256) {
        return yields[_tier - 1];
    }

    /**
     * @notice Gets the current total tiers
     */
    function getMaxTiers() external view returns(uint256) {
        return tiers.length;
    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) external onlyOwner {
        _mint(_to, _tokenId);
        breweryStats[_tokenId] = BreweryStats({
            name: _name, 
            xp: 0, 
            productionRatePerSecondMultiplier: 100 * PRECISION, 
            fermentationPeriodMultiplier: 100 * PRECISION,
            experienceMultiplier: 100 * PRECISION,
            totalYield: 0,
            lastTimeClaimed: block.timestamp
        });
    }

    function giveXP(uint256 _tokenId, uint256 _xp) external onlyOwner {
        breweryStats[_tokenId].xp += _xp;
    }

    /**
     * @notice Levels up a BREWERY 
     */
    function levelUp(uint256 _tokenId) external { 

    }

    /**
     * @notice Claims all the rewards from every node that `msg.sender` owns
     */
    function claimAll() external {

    }

    function pendingMead(uint256 _tokenId) external view returns (uint256) {
        uint256 rewardPeriod = block.timestamp - breweryStats[_tokenId].lastTimeClaimed;
        return rewardPeriod * getProductionRatePerSecond(_tokenId);
    }

    /**
     * @notice Claims the rewards from a specific node
     */
    function claim(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == _msgSender(), "Must be owner of this brewery");

        // Award MEAD tokens
        uint256 rewardPeriod = block.timestamp - breweryStats[_tokenId].lastTimeClaimed;
        uint256 newReward = rewardPeriod * getProductionRatePerSecond(_tokenId);
        meadToken.safeTransferFrom(rewardsPool, _msgSender(), newReward);

        // Check fermentation period and Increase XP
        uint256 fermentationPeriod = getFermentationPeriod(_tokenId);
        uint256 fermentationTime = breweryStats[_tokenId].lastTimeClaimed + fermentationPeriod;

        // Only award XP if we elapsed past the fermentation period
        if (fermentationTime >= block.timestamp) {
            uint256 timeSinceFermentation = block.timestamp - fermentationTime;
            breweryStats[_tokenId].xp += timeSinceFermentation * getExperiencePerSecond(_tokenId);

            // Check and compute a level up (i.e. increasing the brewerys yield)
            uint256 tier = getTier(_tokenId);
            if (tier < tiers.length) {
                if (breweryStats[_tokenId].xp >= tiers[tier]) {
                    breweryStats[_tokenId].productionRatePerSecondMultiplier = yields[tier];
                }
            }
        }

        // Reset the claim timer so that individuals have to wait past the fermentation period again
        breweryStats[_tokenId].lastTimeClaimed = block.timestamp;
    }

    /**
     * @notice Renovations
     */
    function upgrade(uint256 _tokenId, uint256 _renovationId) external {
        Renovation reno = Renovation(renovationAddress);

        require(ownerOf(_tokenId) == _msgSender(), "Must be owner of this brewery");
        require(reno.ownerOf(_renovationId) == _msgSender(), "Must be owner of this renovation");

        // If renovation is type 0 (Production)
        if (reno.getType(_renovationId) == 0) {
            breweryStats[_tokenId].productionRatePerSecondMultiplier = reno.getIntValue(_renovationId);
        } else if (reno.getType(_renovationId) == 1) {
            // Type Fermentation Period
            breweryStats[_tokenId].fermentationPeriodMultiplier = reno.getIntValue(_renovationId);
        }

        reno.consume(_renovationId);
    }
}