pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is ERC721, Ownable {

    struct BreweryStats {
        string name;                           // A unique string
        uint256 xp;                            // A XP value, increased on each claim
        uint256 productionRateMultiplier;      // The amount to increase yield by
        uint256 fermentationPeriodMultiplier;  // The amount to decrease the fermentation period by
        uint256 totalYield;                    // The total yield this brewery has produced
        uint256 lastTimeClaimed;               // The last time this brewery has had a claim
    }

    /// @notice A mapping of unique hashed strings, to a flag that specifies if the brewery name already exists
    mapping (bytes32 => bool) nameExists;

    /// @notice A mapping of token ID to brewery stats
    mapping (uint256 => BreweryStats) stats;

    /// @notice A list of tiers (index) and XP values (value), tiers.length = max tier.
    uint256[] public tiers;

    constructor(string memory _name, string memory _symbol, uint256 _baseDailyYield, uint256 _baseFermentationPeriod) {

    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) onlyOwner {
        bytes32 strHash = keccak256(bytes(_name));
        require(!_nameExists[strHash], "Name exists");
        _mint(_to, _tokenId);
        stats[_tokenId] = BreweryStats({
            name: _name, 
            xp: 0, 
            productionRateMultiplier: 100, 
            fermentationPeriodMultiplier: 100
        });
        _nameExists[strHash] = true;
    }

    function giveXP(uint256 _tokenId, uint256 _xp) onlyOwner {
        stats[_tokenId].xp += _xp;
    }

    /**
     * @notice Claims the rewards
     */
    function claim(uint256 _tokenId) {
        require(msg.sender == _owners[_tokenId], )
    }

    /**
     * @notice Calculates the tier of a particular token ID
     */
    function getTier(uint256 _tokenId) public view returns(uint256) {
        uint256 xp = stats[_tokenId].xp;  // Tier 1: 0 - 99         Tier 2:  100 - 249           Tier 3:     250+
        for(uint i = 0; i < tiers.length; ++i) {
            if (xp > tiers[i]) {
                continue;
            }
            return i + 1;
        }
    }

    /**
     * @notice Gets the current total tiers
     */
    function getMaxTiers() external view returns(uint256) {
        return tiers.length;
    }

    /**
     * @notice Adds a tier and it's associated with XP value
     */
    function addTier(uint256 _xp) external onlyOwner {
         tiers.push(_xp);
    }

    /**
     * @notice Edits the XP value of a particular tier
     */
    function editTier(uint256 _tier, uint256 _xp) external onlyOwner {
        require(tiers.length >= _tier, "Tier doesnt exist");
        tiers[_tier - 1] = _xp;
    }

    /**
     * @notice Clears the tiers array
     * @dev Should only be used if wrong tiers were added
     */
    function clearTiers() external onlyOwner {
        delete tiers;
    }
}