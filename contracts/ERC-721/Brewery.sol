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
    /// @dev tiers.length = tier count    and      (tiers.length - 1) = max tier
    uint256[] public tiers;

    /// @notice A list of tiers (index) and production rates (value)
    /// @dev tiers.length = max tier
    /// @dev yields are in units that factor in the decimals of MEAD
    uint256[] public yields;

    /// @notice The base fermentation period in seconds
    uint256 public fermentationPeriod;

    /// @notice The base experience amount awarded for each second past the fermentation period
    uint256 public experiencePerSecond;

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
        uint256 _fermentationPeriod,
        uint256 _experiencePerSecond
    ) external initializer {
        __ERC721_init(NAME, SYMBOL);
        __ERC721Enumerable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, address(this));

        settings = TavernSettings(_tavernSettings);

        fermentationPeriod = _fermentationPeriod;
        experiencePerSecond = _experiencePerSecond;

        globalProductionRateMultiplier = 1e4;     // 10000 (100.00% or 1.0x)
        globalFermentationPeriodMultiplier = 1e4; // 10000 (100.00% or 1.0x)
        globalExperienceMultiplier = 1e4;         // 10000 (100.00% or 1.0x)

        startTime = block.timestamp;
        tradingEnabled = false;
    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     * @dev The BreweryPurchaseHelper and other helpers will use this function to create BREWERYs
     */
    function mint(address _to, string memory _name) public isRole(MINTER_ROLE) {
        require(balanceOf(_to) + 1 <= settings.walletLimit(), "Cant go over limit");
        uint256 tokenId = totalSupply() + 1;
        _safeMint(_to, tokenId);
        breweryStats[tokenId] = BreweryStats({
            name: _name,
            type_: 0,                                    // Default type is 0
            tier: 0,                                     // Default tier is 0 (Tier 1)
            enabled: true,                               // Start earning straight away
            xp: 0,
            productionRatePerSecondMultiplier: 1e4,      // Default to 1.0x production rate
            fermentationPeriodMultiplier: 1e4,           // Default to 1.0x fermentation period
            experienceMultiplier: 1e4,                   // Default to 1.0x experience
            totalYield: 0,
            lastTimeClaimed: block.timestamp
        });
    }

    /**
     * @notice Compounds all pending MEAD into new BREWERYs!
     */
    function compoundAll() external {
        uint256 totalRewards = getTotalPendingMead(msg.sender);
        uint256 breweryCount = totalRewards / settings.breweryCost();
        require(breweryCount > 0, "You dont have enough pending MEAD");
        _compound(breweryCount);
    }

    /**
     * @notice Function that
     */
    function compound(uint256 _amount) public {
        uint256 totalRewards = getTotalPendingMead(msg.sender);
        uint256 breweryCount = totalRewards / settings.breweryCost();
        require(breweryCount >= _amount, "Cannot compound this amount");
        _compound(_amount);
    }

    /**
     * @notice Compounds MEAD
     */
    function _compound(uint256 _amount) internal {
        uint256 totalRewards = getTotalPendingMead(msg.sender);
        uint256 cost = _amount * settings.breweryCost();
        require(totalRewards >= cost, "You dont have enough pending MEAD");

        uint256 count = balanceOf(msg.sender);
        for(uint256 i = 0; i < count; ++i) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
            if (totalRewards >= settings.breweryCost()) {
                totalRewards -= pendingMead(tokenId);
                breweryStats[tokenId].lastTimeClaimed = block.timestamp;
                mint(msg.sender, "");
            }
        }
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
        uint256 dailyYield = yields[breweryStats[_tokenId].tier] * breweryStats[_tokenId].productionRatePerSecondMultiplier * globalProductionRateMultiplier;
        return (dailyYield / 86400) / (1e4 * 1e4);
    }

    /**
     * @notice Calculates the fermentation period in seconds
     */
    function getFermentationPeriod(uint256 _tokenId) public view returns(uint256) {
        uint256 totalPeriod = fermentationPeriod * breweryStats[_tokenId].fermentationPeriodMultiplier * globalFermentationPeriodMultiplier;
        return totalPeriod / (1e4 * 1e4);
    }

    /**
     * @notice Calculates how much experience people earn per second
     */
    function getExperiencePerSecond(uint256 _tokenId) public view returns(uint256) {
        uint256 xpPerSecond = experiencePerSecond * breweryStats[_tokenId].experienceMultiplier * globalExperienceMultiplier;
        return xpPerSecond / (1e4 * 1e4);
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

    function getTiers() external view returns(uint256[] memory) {
        return tiers;
    }

    function getYields() external view returns(uint256[] memory) {
        return yields;
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
    function getRewardPeriod(uint256 lastClaimed) public view returns (uint256) {
        // If we haven't passed the last time since we claimed (also the create time) then return zero as we haven't started yet
        // If we we passed the last time since we claimed (or the create time), but we haven't passed it 
        if (block.timestamp < startTime) {
            return 0;
        } else if (lastClaimed < startTime) {
            return block.timestamp - startTime;
        } else {
            return block.timestamp - lastClaimed;
        }
    }

    /**
     * @notice Returns the unclaimed MEAD rewards for a given BREWERY 
     */
    function pendingMead(uint256 _tokenId) public view returns (uint256) {
        // rewardPeriod is 0 when currentTime is less than start time
        uint256 rewardPeriod = getRewardPeriod(breweryStats[_tokenId].lastTimeClaimed);
        return rewardPeriod * getProductionRatePerSecond(_tokenId);
    }

    /**
     * @notice Gets the total amount of pending MEAD across all of this users BREWERYs
     */
    function getTotalPendingMead(address account) public view returns (uint256) {
        uint256 totalPending = 0;
        uint256 count = balanceOf(account);
        for(uint256 i = 0; i < count; ++i) {
            totalPending += pendingMead(tokenOfOwnerByIndex(account, i));
        }
        return totalPending;
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
        uint256 xpStartTime = startTime > breweryStats[_tokenId].lastTimeClaimed ? startTime : breweryStats[_tokenId].lastTimeClaimed;
        uint256 fermentationTime = xpStartTime + fermentationPeriod;

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
        uint256 totalRewards = pendingMead(_tokenId);
        if (totalRewards > 0) {
            uint256 claimTax = getBrewersTax(msg.sender);
            uint256 treasuryAmount = totalRewards * claimTax / 1e4;
            uint256 rewardAmount = totalRewards - treasuryAmount;

            // Transfer the resulting mead from the rewards pool to the user
            // Transfer the taxed portion of mead from the rewards pool to the treasury
            IERC20Upgradeable mead = IERC20Upgradeable(settings.mead());
            mead.safeTransferFrom(settings.rewardsPool(), msg.sender, rewardAmount);
            mead.safeTransferFrom(settings.rewardsPool(), settings.tavernsKeep(), treasuryAmount);
        
            breweryStats[_tokenId].totalYield += totalRewards;
        }

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
    function addXP(uint256 _tokenId, uint256 _xp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].xp += _xp;
    }

    /**
     * @notice Removes XP from a BREWERY
     */
    function removeXP(uint256 _tokenId, uint256 _xp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].xp -= _xp;
    }

    /**
     * @notice Sets the name of the BREWERY
     */
    function setBreweryName(uint256 _tokenId, string memory _name) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].name = _name;
    }

    /**
     * @notice Sets the type of the BREWERY
     */
    function setBreweryType(uint256 _tokenId, uint256 _type_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].type_ = _type_;
    }

    /**
     * @notice Sets the tier of a BREWERY
     */
    function setBreweryTier(uint256 _tokenId, uint256 _tier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].tier = _tier;
    }

    /**
     * @notice Sets a BREWERY to whether it can produce or not
     */
    function setEnableBrewery(uint256 _tokenId, bool _b) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].enabled = _b;
    }

    /**
     * @notice Sets the experience for a BREWERY
     */
    function setBreweryXp(uint256 _tokenId, uint256 _xp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].xp = _xp;
    }

    /**
     * @notice Sets the base production rate that all new minted BREWERYs start with
     */
    function setBreweryProductionRateMultiplier(uint256 _tokenId, uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].productionRatePerSecondMultiplier = _value;
    }

    /**
     * @notice Sets the base fermentation period for all BREWERYs
     */
    function setBreweryFermentationPeriodMultiplier(uint256 _tokenId, uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].fermentationPeriodMultiplier = _value;
    }

    /**
     * @notice Sets the experience rate for all BREWERYs
     */
    function setBreweryExperienceMultiplier(uint256 _tokenId, uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        breweryStats[_tokenId].experienceMultiplier = _value;
    }

    /**
     * @notice Sets the fermentation period for all BREWERYs
     */
    function setBaseFermentationPeriod(uint256 _baseFermentationPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fermentationPeriod = _baseFermentationPeriod;
    }

    /**
     * @notice Sets the experience rate for all BREWERYs
     */
    function setBaseExperiencePerSecond(uint256 _baseExperiencePerSecond) external onlyRole(DEFAULT_ADMIN_ROLE) {
        experiencePerSecond = _baseExperiencePerSecond;
    }

    /**
     * @notice Sets the production rate multiplier for all new minted BREWERYs start with
     */
    function setGlobalProductionRatePerSecond(uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalProductionRateMultiplier = _value;
    }

    /**
     * @notice Sets the fermentation period multiplier for all BREWERYs
     */
    function setGlobalFermentationPeriod(uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalFermentationPeriodMultiplier = _value;
    }

    /**
     * @notice Sets the experience rate multiplier for all BREWERYs
     */
    function setGlobalExperiencePerSecond(uint256 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalExperienceMultiplier = _value;
    }
}