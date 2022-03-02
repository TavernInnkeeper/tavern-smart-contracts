pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoePair.sol";

import "./Renovation.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is ERC721Enumerable, Ownable {
    /// @notice A descriptive name for a collection of NFTs in this contract
    string private constant NAME = "Brewery";

    /// @notice An abbreviated name for NFTs in this contract
    string private constant SYMBOL = "BREWERY";

    /// @notice Address of USDC
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    /// @notice Used to give extra precision for percentages
    uint256 public constant PRECISION = 1e10;

    /// @notice The contract address of the MEAD token
    IERC20 public meadToken;

    /// @notice The address for the renovation
    address public renovationAddress;

    struct BreweryStats {
        string name;                           // A unique string
        uint256 xp;                            // A XP value, increased on each claim
        uint256 productionRateMultiplier;      // The percentage increase to base yield
        uint256 fermentationPeriodMultiplier;  // The percentage decrease to the fermentation period
        uint256 experienceMultiplier;          // The percentage increase to experience gain
        uint256 totalYield;                    // The total yield this brewery has produced
        uint256 lastTimeClaimed;               // The last time this brewery has had a claim
    }

    /// @notice The base amount of daily MEAD that each Brewery earns
    uint256 public baseProductionRate;

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

    constructor(address _meadTokenAddress, address _routerAddress, address _tavernsKeep, address _renovationAddress, uint256 _initialSupply, uint256 _baseDailyYield, uint256 _baseFermentationPeriod) ERC721(NAME, SYMBOL) {
        renovationAddress = _renovationAddress;
        meadToken = IERC20(_meadTokenAddress);
    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) external onlyOwner {
        _mint(_to, _tokenId);
        breweryStats[_tokenId] = BreweryStats({
            name: _name, 
            xp: 0, 
            productionRateMultiplier: 100 * PRECISION, 
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

    /**
     * @notice Claims the rewards from a specific node
     */
    function claim(uint256 _tokenId) external {
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
                    breweryStats[_tokenId].productionRateMultiplier = yields[tier];
                }
            }
        }

        // Award MEAD tokens

        // Reset the claim timer so that individuals have to wait past the fermentation period again
        breweryStats[_tokenId].lastTimeClaimed = block.timestamp;
    }

    /**
     * @notice Renovations
     */
    function upgrade(uint256 _tokenId, uint256 _renovationId) external {
        Renovation reno = Renovation(renovationAddress);

        // If renovation is type 0 (Productio)
        if (reno.getType(_renovationId) == 0) {
            breweryStats[_tokenId].productionRateMultiplier = reno.getIntValue(_renovationId);
        } else if (reno.getType(_renovationId) == 1) {
            // Type Fermentation Period
            breweryStats[_tokenId].fermentationPeriodMultiplier = reno.getIntValue(_renovationId);
        }

        reno.consume(_renovationId);
    }

    /**
     * @notice Calculates the tier of a particular token ID
     */
    function getTier(uint256 _tokenId) public view returns(uint256) {
        uint256 xp = breweryStats[_tokenId].xp;  // Tier 1: 0 - 99         Tier 2:  100 - 249           Tier 3:     250+
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

    function getProductionRate(uint256 _tokenId) public view returns(uint256) {
        return baseProductionRate * breweryStats[_tokenId].productionRateMultiplier / PRECISION;
    }

    function getFermentationPeriod(uint256 _tokenId) public view returns(uint256) {
        return baseFermentationPeriod * breweryStats[_tokenId].fermentationPeriodMultiplier / PRECISION;
    }

    function getExperiencePerSecond(uint256 _tokenId) public view returns(uint256) {
        return baseExperiencePerSecond * breweryStats[_tokenId].experienceMultiplier / PRECISION;
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
     * @notice Purchases a node
     */
    function _buyBrewery() internal {
        // TODO: Logic
    }
}