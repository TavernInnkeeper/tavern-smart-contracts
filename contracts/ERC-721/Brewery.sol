pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Renovation.sol";
import "../TavernSettings.sol";

import "../interfaces/IClassManager.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is Initializable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice A descriptive name for a collection of NFTs in this contract
    string private constant NAME = "Brewery";

    /// @notice An abbreviated name for NFTs in this contract
    string private constant SYMBOL = "BREWERY";
    
    /// @notice The data contract containing all of the necessary settings
    TavernSettings public settings;

    /// @notice Whether or not trading is enabled 
    bool public tradingEnabled;

    struct BreweryStats {
        string  name;                                 // A unique string
        uint32  type_;                                // The type of BREWERY (results in a different skin)
        uint32  tier;                                 // The index of tier to use
        uint256 xp;                                   // A XP value, increased on each claim
        uint256 productionRatePerSecondMultiplier;    // The percentage increase to base yield
        uint256 fermentationPeriodMultiplier;         // The percentage decrease to the fermentation period
        uint256 experienceMultiplier;                 // The percentage increase to experience gain
        uint256 totalYield;                           // The total yield this brewery has produced
        uint256 lastTimeClaimed;                      // The last time this brewery has had a claim
    }

    /// @notice A mapping of token ID to brewery stats
    mapping (uint256 => BreweryStats) public breweryStats;

    /// @notice A list of tiers (index) and XP values (value)
    /// @dev tiers.length = max tier
    uint256[] public tiers;

    /// @notice A list of tiers (index) and production rates (value)
    /// @dev tiers.length = max tier
    /// @dev yields are in units that factor in the decimals of MEAD
    uint256[] public yields;

    /// @notice The base amount of daily MEAD that each Brewery earns
    uint256 public baseProductionRatePerSecond;

    /// @notice The base fermentation period in seconds
    uint256 public baseFermentationPeriod;

    /// @notice The base experience amount awarded for each second past the fermentation period
    uint256 public baseExperiencePerSecond;

    /// @notice The control variable to increase production rate globally
    uint256 public globalProductionRateMultiplier;

    /// @notice The control variable to decrease fermentation period globally
    uint256 public globalFermentationPeriodMultiplier;

    /// @notice The control variable to increase experience gain
    uint256 public globalExperienceMultiplier;

    /// @notice Emitted events
    event Claim(address indexed owner, uint256 tokenId, uint256 amount, uint256 timestamp);
    event LevelUp(address indexed owner, uint256 tokenId, uint32 tier, uint256 xp, uint256 timestamp);

    function initialize(
        address _tavernSettings,
        uint256 _baseDailyYield,
        uint256 _baseFermentationPeriod,
        uint256 _baseExperiencePerSecond
    ) external initializer {
        __ERC721_init(NAME, SYMBOL);
        __ERC721Enumerable_init();
        __Ownable_init();

        settings = TavernSettings(_tavernSettings);

        baseProductionRatePerSecond = _baseDailyYield / 86400;
        baseFermentationPeriod = _baseFermentationPeriod;
        baseExperiencePerSecond = _baseExperiencePerSecond;

        globalProductionRateMultiplier = 100 * settings.PRECISION();
        globalFermentationPeriodMultiplier = 100 * settings.PRECISION();
        globalExperienceMultiplier = 100 * settings.PRECISION();
    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) external onlyOwner {
        _safeMint(_to, _tokenId);
        breweryStats[_tokenId] = BreweryStats({
            name: _name,
            tier: 0,
            xp: 0,
            productionRatePerSecondMultiplier: 100 * settings.PRECISION(), // Default to 1.0x production rate
            fermentationPeriodMultiplier: 100 * settings.PRECISION(),      // Default to 1.0x fermentation period
            experienceMultiplier: 100 * settings.PRECISION(),              // Default to 1.0x experience
            totalYield: 0,
            lastTimeClaimed: block.timestamp
        });
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        string memory tokenURI = tokenURIs[breweryStats[tokenId].type_][breweryStats[tokenId].tier];
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenURI)) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return "";
    }

    /**
     * @notice Approves an address to spend a particular token
     */
    function _approve(address to, uint256 tokenId) internal virtual override {
        require(tradingEnabled, "Trading is disabled");
        super._approve(to, tokenId);
    }

    /**
     * @notice Handles the internal transfer of any BREWERY
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(tradingEnabled, "Trading is disabled");
        super._transfer(from, to, tokenId);
    }

    /**
     * @notice Calculates the production rate in MEAD for a particular BREWERY NFT
     */
    function getProductionRatePerSecond(uint256 _tokenId) public view returns(uint256) {
        // The rate of the brewery based on its tier
        uint256 breweryRate = yields[breweryStats[_tokenId].tier];

        // The multiplier to add to it based on its renovations
        uint256 multiplier = breweryStats[_tokenId].productionRatePerSecondMultiplier / (100 * settings.PRECISION());

        // Control multiplier for periods of extra yield (i.e. double yield weekends), usually remains as 1.0x
        uint256 global = globalProductionRateMultiplier / (100 * settings.PRECISION());

        // Multipliers are multiplicative and not additive
        return breweryRate * multiplier * global;
    }

    /**
     * @notice Calculates the fermentation period in seconds
     */
    function getFermentationPeriod(uint256 _tokenId) public view returns(uint256) {
        return baseFermentationPeriod * breweryStats[_tokenId].fermentationPeriodMultiplier / (100 * settings.PRECISION()) * globalFermentationPeriodMultiplier;
    }

    /**
     * @notice Calculates how much experience people earn per second
     */
    function getExperiencePerSecond(uint256 _tokenId) public view returns(uint256) {
        return baseExperiencePerSecond * breweryStats[_tokenId].experienceMultiplier / (100 * settings.PRECISION()) * globalExperienceMultiplier;
    }

    /**
     * @notice Calculates the tier of a particular token ID
     */
    function getTier(uint256 _tokenId) public view returns(uint256) {
        require(tiers.length > 0, "Tiers not set!");
        uint256 xp = breweryStats[_tokenId].xp;
        for(uint i = 0; i < tiers.length; ++i) {
            if (xp > tiers[i]) {
                continue;
            }
            return i;
        }
        return tiers.length;
    }

    /**
     * @notice Returns the current yield based on XP
     */
    function getYield(uint256 _tokenId) public view returns(uint256) {
        return yields[getTier(_tokenId) - 1];
    }

    /**
     * @notice Returns the yield based on tier
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
     * @notice Claims all the rewards from every node that `msg.sender` owns
     */
    function claimAll() external {
        uint256 balance = balanceOf(_msgSender());
        for (uint256 index = 0; index < balance; index = index + 1) {
            claim(tokenOfOwnerByIndex(_msgSender(), index));
        }
    }

    /**
     * @notice Returns the unclaimed MEAD rewards for a given BREWERY 
     */
    function pendingMead(uint256 _tokenId) public view returns (uint256) {
        uint256 rewardPeriod = block.timestamp - breweryStats[_tokenId].lastTimeClaimed;
        return rewardPeriod * getProductionRatePerSecond(_tokenId);
    }

    /**
     * @notice Returns the brewers tax for the particular brewer
     */
    function getBrewersTax(address brewer) public view returns (uint256) {
        uint32 class = IClassManager(settings.classManager()).getClass(brewer);
        return settings.classTaxes(class);
    }

    /**
     * @notice Claims the rewards from a specific node
     */
    function claim(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == _msgSender(), "Must be owner of this BREWERY");
        require(getApproved(_tokenId) == address(0), "BREWERY is approved for spending/listed");

        // Award MEAD tokens
        uint256 totalRewards = pendingMead(_tokenId);
        uint256 claimTax = getBrewersTax(msg.sender);
        uint256 treasuryAmount = totalRewards * (claimTax / 100 * settings.PRECISION());
        uint256 rewardAmount = totalRewards - treasuryAmount;

        // Transfer the resulting mead from the rewards pool to the user
        // Transfer the taxed portion of mead from the rewards pool to the treasury
        IERC20Upgradeable mead = IERC20Upgradeable(address(settings.mead()));
        mead.safeTransferFrom(settings.rewardsPool(), msg.sender, rewardAmount);
        mead.safeTransferFrom(settings.rewardsPool(), settings.tavernsKeep(), treasuryAmount);

        // Check fermentation period and Increase XP
        uint256 fermentationPeriod = getFermentationPeriod(_tokenId);
        uint256 fermentationTime = breweryStats[_tokenId].lastTimeClaimed + fermentationPeriod;

        // Only award XP if we elapsed past the fermentation period
        if (fermentationTime >= block.timestamp) {
            uint256 timeSinceFermentation = block.timestamp - fermentationTime;
            breweryStats[_tokenId].xp += timeSinceFermentation * getExperiencePerSecond(_tokenId);

            // Check and compute a level up (i.e. increasing the brewerys yield)
            uint256 tier = getTier(_tokenId);
            if (tier < tiers.length && breweryStats[_tokenId].tier != tier) {
                breweryStats[_tokenId].tier = tier;
                emit LevelUp(msg.sender, _tokenId, tier, breweryStats[_tokenId].xp, block.timestamp);
            }
        }

        // Reset the claim timer so that individuals have to wait past the fermentation period again
        breweryStats[_tokenId].lastTimeClaimed = block.timestamp;

        emit Claim(_msgSender(), _tokenId, rewardAmount, block.timestamp);
    }

    /**
     * @notice Handle renovation upgrades.
     * @dev Requires msg.sender to own the BREWERY, and to own a renovation
     */
    function upgrade(uint256 _tokenId, uint256 _renovationId) external {
        Renovation renovation = Renovation(settings.renovationAddress());

        require(ownerOf(_tokenId) == _msgSender(), "Must be owner of this brewery");
        require(renovation.ownerOf(_renovationId) == _msgSender(), "Must be owner of this renovation");

        // Handle production rate upgrades
        if (renovation.getType(_renovationId) == renovation.PRODUCTION_RATE()) {
            breweryStats[_tokenId].productionRatePerSecondMultiplier = renovation.getIntValue(_renovationId);
        } 
        
        // Handle fermentation period upgrades
        if (renovation.getType(_renovationId) == renovation.FERMENTATION_PERIOD()) {
            breweryStats[_tokenId].fermentationPeriodMultiplier = renovation.getIntValue(_renovationId);
        } 
        
        // Handle experience rate upgrades
        if (renovation.getType(_renovationId) == renovation.EXPERIENCE_BOOST()) {
            breweryStats[_tokenId].experienceMultiplier = renovation.getIntValue(_renovationId);
        } 
        
        // Handle type/skin changes
        if (renovation.getType(_renovationId) == renovation.TYPE_CHANGE()) {
            breweryStats[_tokenId].type_ = renovation.getIntValue(_renovationId);
        }

        // Handle type/skin changes
        if (renovation.getType(_renovationId) == renovation.NAME_CHANGE()) {
            breweryStats[_tokenId].name = renovation.getStrValue(_renovationId);
        }

        // Consume, destroy and burn the renovation!!!
        renovation.consume(_renovationId);
    }


    /**
     * ================================================================
     *                   ADMIN FUNCTIONS
     * ================================================================
     */

    /**
     * @notice Changes whether trading/transfering these NFTs is enabled or not
     */
    function setTradingEnabled(bool _b) external onlyOwner {
        tradingEnabled = _b;
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
     * @notice Gives a certain amount of XP to a BREWERY
     */
    function giveXP(uint256 _tokenId, uint256 _xp) external onlyOwner {
        breweryStats[_tokenId].xp += _xp;
    }

    /**
     * @notice Sets a BREWERY to whether it can produce or not
     */
    function setEnableBrewery(uint256 _tokenId, bool _b) external onlyOwner {
        breweryStats[_tokenId].enabled = _b;
    }

    /**
     * @notice Sets the base fermentation period for all BREWERYs
     */
    function setBaseFermentationPeriod(uint256 _baseFermentationPeriod) external onlyOwner {
        baseFermentationPeriod = _baseFermentationPeriod;
    }

    /**
     * @notice Sets the experience rate for all BREWERYs
     */
    function setBaseExperiencePerSecond(uint256 _baseExperiencePerSecond) external onlyOwner {
        baseExperiencePerSecond = _baseExperiencePerSecond;
    }

    /**
     * @notice Sets the base production rate that all new minted BREWERYs start with
     */
    function setBaseProductionRatePerSecond(uint256 _baseProductionRatePerSecond) external onlyOwner {
        baseProductionRatePerSecond = _baseProductionRatePerSecond;
    }
}