pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is ERC721, Ownable {

    struct BreweryStats {
        string name,
        uint256 experience,
        uint256 dailyYield,
        uint256 fermentationPeriod
    };

    /// @notice The base daily yield, all new Brewery NFTs will begin with this
    uint256 public baseDailyYield;

    /// @notice The base daily yield, all new Brewery NFTs will begin with this
    uint256 public baseFermentationPeriod;

    /// @notice A mapping of token ID to brewery stats
    mapping (uint256 => BreweryStats) stats;

    /// @notice A mapping of unique hashed strings, to a flag that specifies if the brewery name already exists
    mapping (bytes32 => bool) nameExists;

    constructor(string memory _name, string memory _symbol, uint256 baseDailyYield, uint256 baseFermentationPeriod) {

    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) {
        bytes32 strHash = keccak256(_name);
        require(!_nameExists[strHash], "Name exists");
        _mint(_to, _tokenId)
        stats[_tokenId] = { _name, 0, baseDailyYield, baseFermentationPeriod };
    }
}