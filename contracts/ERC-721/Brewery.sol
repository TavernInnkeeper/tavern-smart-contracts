pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./Renovation.sol";
import "../TavernSettings.sol";
import "../interfaces/IClassManager.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is Initializable, ERC721EnumerableUpgradeable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice A descriptive name for a collection of NFTs in this contract
    string private constant NAME = "Brewery";

    /// @notice An abbreviated name for NFTs in this contract
    string private constant SYMBOL = "BREWERY";

    /// @notice The base URI of the NFT
    string private baseURI;

    mapping(uint256 => mapping(uint256 => string)) tokenURIs;
    
    /// @notice The data contract containing all of the necessary settings
    TavernSettings public settings;

    /// @notice Whether or not trading is enabled 
    bool public tradingEnabled;

    /// @notice BREWERYs can't earn before this time
    uint256 public startTime;

    struct BreweryStats {
        string  name;                              // A unique string
        uint256 type_;                             // The type of BREWERY (results in a different skin)
        uint256 tier;                              // The index of tier to use
        bool    enabled;                           // Whether this BREWERY has its rewards enabled
        uint256 xp;                                // A XP value, increased on each claim
        uint256 productionRatePerSecondMultiplier; // The percentage increase to base yield
        uint256 fermentationPeriodMultiplier;      // The percentage decrease to the fermentation period
        uint256 experienceMultiplier;              // The percentage increase to experience gain
        uint256 totalYield;                        // The total yield this brewery has produced
        uint256 lastTimeClaimed;                   // The last time this brewery has had a claim
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
    event LevelUp(address indexed owner, uint256 tokenId, uint256 tier, uint256 xp, uint256 timestamp);

    /// @notice The specific role to give to the Brewery Purchase Helper so it can mint BREWERYs
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Incorrect role!");
        _;
    }

    function initialize(
        address _tavernSettings,
        uint256 _baseDailyYield,
        uint256 _baseFermentationPeriod,
        uint256 _baseExperiencePerSecond
    ) external initializer {
        __ERC721_init(NAME, SYMBOL);
        __ERC721Enumerable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        startTime = block.timestamp;
        tradingEnabled = false;

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
     * @dev The BreweryPurchaseHelper and other helpers will use this function to create BREWERYs
     */
    function mint(address _to, string memory _name) external isRole(MINTER_ROLE) {
        require(balanceOf(_to) < settings.walletLimit(), "Cant go over limit");
        uint256 tokenId = totalSupply() + 1;
        _safeMint(_to, tokenId);
        breweryStats[tokenId] = BreweryStats({
            name: _name,
            type_: 0,                                                      // Default type is 0
            tier: 0,                                                       // Default tier is 0 (Tier 1)
            enabled: true,                                                 // Start earning straight away
            xp: 0,
            productionRatePerSecondMultiplier: 100 * settings.PRECISION(), // Default to 1.0x production rate
            fermentationPeriodMultiplier: 100 * settings.PRECISION(),      // Default to 1.0x fermentation period
            experienceMultiplier: 100 * settings.PRECISION(),              // Default to 1.0x experience
            totalYield: 0,
            lastTimeClaimed: block.timestamp
        });
    }

    /**
     * @dev Unused, specified to suppress compiler error for duplicates function from multiple parents
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the total token URI based on the base URI, and the tokens type and tier
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseNFTURI = _baseURI();
        string memory tokenNFTURI = tokenURIs[breweryStats[tokenId].type_][breweryStats[tokenId].tier];
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseNFTURI, tokenNFTURI)) : "";
    }

    /**
     * @notice The base URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
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
        uint256 breweryRate = yields[breweryStats[_tokenId].tier] / 86400;

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

        // The multiplier (values below 1.0 are good)
        uint256 multiplier = breweryStats[_tokenId].fermentationPeriodMultiplier / (100 * settings.PRECISION());

        // Control multiplier
        uint256 global = globalFermentationPeriodMultiplier / (100 * settings.PRECISION());

        return baseFermentationPeriod * multiplier * global;
    }

    /**
     * @notice Calculates how much experience people earn per second
     */
    function getExperiencePerSecond(uint256 _tokenId) public view returns(uint256) {
        return baseExperiencePerSecond * breweryStats[_tokenId].experienceMultiplier * globalExperienceMultiplier / (100 * settings.PRECISION() * 100 * settings.PRECISION());
    }

    /**
     * @notice Calculates the tier of a particular token ID
     */
    function getTier(uint256 _tokenId) public view returns(uint256) {
        require(tiers.length > 0, "Tiers not set!");
        uint256 xp = breweryStats[_tokenId].xp;
        for(uint256 i = tiers.length - 1; i > 0; i = i - 1) {
            if (xp > tiers[i]) {
                return i;
            }
        }
        return 0;
    }

    /**
     * @notice Returns the current yield based on XP
     */
    function getYield(uint256 _tokenId) public view returns(uint256) {
        return yields[getTier(_tokenId)];
    }

    /**
     * @notice Returns the yield based on tier
     */
    function getYieldFromTier(uint256 _tier) public view returns(uint256) {
        return yields[_tier];
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
     * @notice Helper to calculate the reward period with respect to a start time
     */
    function _getRewardPeriod(uint256 currentTime, uint256 lastClaimed) internal view returns (uint256) {
        // If we haven't passed the last time since we claimed (also the create time) then return zero as we haven't started yet
        // If we we passed the last time since we claimed (or the create time), but we haven't passed it 
        if (currentTime < startTime) {
            return 0;
        } else if (lastClaimed < startTime) {
            return currentTime - startTime;
        } else{
            return currentTime - lastClaimed;
        }
    }

    /**
     * @notice Returns the unclaimed MEAD rewards for a given BREWERY 
     */
    function pendingMead(uint256 _tokenId) public view returns (uint256) {
        // rewardPeriod is 0 when currentTime is less than start time
        uint256 rewardPeriod = _getRewardPeriod(block.timestamp, breweryStats[_tokenId].lastTimeClaimed);
        return rewardPeriod * getProductionRatePerSecond(_tokenId);
    }

    /**
     * @notice Returns the brewers tax for the particular brewer
     */
    function getBrewersTax(address brewer) public view returns (uint256) {
        uint256 class = IClassManager(settings.classManager()).getClass(brewer);
        return settings.classTaxes(class);
    }

    /**
     * @notice Calculates the pending XP rewards to view on the front end
     */
    function getPendingXp(uint256 _tokenId) public view returns (uint256) {
        // Check fermentation period and Increase XP
        uint256 fermentationPeriod = getFermentationPeriod(_tokenId);
        uint256 fermentationTime = breweryStats[_tokenId].lastTimeClaimed + fermentationPeriod;

        // Only award XP if we elapsed past the fermentation period
        if (block.timestamp >= fermentationTime) {
            uint256 timeSinceFermentation = block.timestamp - fermentationTime;
            return timeSinceFermentation * getExperiencePerSecond(_tokenId);
        } else {
            return 0;
        }
    }

    /**
     * @notice Claims the rewards from a specific node
     */
    function claim(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == _msgSender(), "Must be owner of this BREWERY");
        require(getApproved(_tokenId) == address(0), "BREWERY is approved for spending/listed");

        // Award MEAD tokens
        // uint256 totalRewards = pendingMead(_tokenId);
        // if (totalRewards > 0) {
        //     uint256 claimTax = getBrewersTax(msg.sender);
        //     uint256 treasuryAmount = totalRewards * (claimTax / 100 * settings.PRECISION());
        //     uint256 rewardAmount = totalRewards - treasuryAmount;

        //     // Transfer the resulting mead from the rewards pool to the user
        //     // Transfer the taxed portion of mead from the rewards pool to the treasury
        //     IERC20Upgradeable mead = IERC20Upgradeable(address(settings.mead()));
        //     mead.safeTransferFrom(settings.rewardsPool(), msg.sender, rewardAmount);
        //     mead.safeTransferFrom(settings.rewardsPool(), settings.tavernsKeep(), treasuryAmount);
        //
        //     breweryStats[_tokenId].totalYield += totalRewards;
        // }

        // Award XP
        breweryStats[_tokenId].xp += getPendingXp(_tokenId);

        // Check and compute a level up (i.e. increasing the brewerys yield)
        uint256 tier = getTier(_tokenId);
        if (tier < tiers.length && breweryStats[_tokenId].tier != tier) {
            breweryStats[_tokenId].tier = tier;
            emit LevelUp(msg.sender, _tokenId, tier, breweryStats[_tokenId].xp, block.timestamp);
        }

        // Reset the claim timer so that individuals have to wait past the fermentation period again
        breweryStats[_tokenId].lastTimeClaimed = block.timestamp;
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
     * @notice Sets a token URI for a given type and given tier
     */
    function setBaseURI(string memory _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _uri;
    }

    /**
     * @notice Sets a token URI for a given type and given tier
     */
    function setTokenURI(uint256 _type, uint256 _tier, string memory _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenURIs[_type][_tier] = _uri;
    }

    /**
     * @notice Updates the settings contract
     */
    function setSettings(address _settings) external onlyRole(DEFAULT_ADMIN_ROLE) {
        settings = TavernSettings(_settings);
    }
    
    /**
     * @notice Sets the starting time
     */
    function setStartTime(uint256 _startTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        startTime = _startTime;
    }

    /**
     * @notice Changes whether trading/transfering these NFTs is enabled or not
     */
    function setTradingEnabled(bool _b) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tradingEnabled = _b;
    }

    /**
     * @notice Adds a tier and it's associated with XP value
     */
    function addTier(uint256 _xp, uint256 _yield) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tiers.push(_xp);
        yields.push(_yield);
    }

    /**
     * @notice Edits the XP value of a particular tier
     */
    function editTier(uint256 _tier, uint256 _xp, uint256 _yield) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tiers.length >= _tier, "Tier doesnt exist");
        tiers[_tier] = _xp;
        yields[_tier] = _yield;
    }

    /**
     * @notice Clears the tiers array
     * @dev Should only be used if wrong tiers were added
     */
    function clearTiers() external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete tiers;
        delete yields;
    }

    /**
     * @notice Gives a certain amount of XP to a BREWERY
     */
    function giveXP(uint256 _tokenId, uint256 _xp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].xp += _xp;
    }

    /**
     * @notice Sets a BREWERY to whether it can produce or not
     */
    function setEnableBrewery(uint256 _tokenId, bool _b) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].enabled = _b;
    }

    /**
     * @notice Sets the base fermentation period for all BREWERYs
     */
    function setBaseFermentationPeriod(uint256 _baseFermentationPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseFermentationPeriod = _baseFermentationPeriod;
    }

    /**
     * @notice Sets the experience rate for all BREWERYs
     */
    function setBaseExperiencePerSecond(uint256 _baseExperiencePerSecond) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseExperiencePerSecond = _baseExperiencePerSecond;
    }

    /**
     * @notice Sets the base production rate that all new minted BREWERYs start with
     */
    function setBaseProductionRatePerSecond(uint256 _baseProductionRatePerSecond) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseProductionRatePerSecond = _baseProductionRatePerSecond;
    }
}