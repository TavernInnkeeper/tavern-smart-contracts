pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoePair.sol";

/**
 * @notice Brewerys are a custom ERC721 (NFT) that can gain experience and level up. They can also be upgraded.
 */
contract Brewery is ERC721, Ownable {
    /// @notice A descriptive name for a collection of NFTs in this contract
    string private constant NAME = "Brewery";

    /// @notice An abbreviated name for NFTs in this contract
    string private constant SYMBOL   = "BREWERY";

    /// @notice Address of USDC
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    /// @notice The contract address of the MEAD token
    IERC20 public meadToken;

    /// @notice The wallet address of the governing treasury
    address public tavernsKeep;

    /// @notice The address of the dex router
    IJoeRouter02 public dexRouter;

    /// @notice The address of the pair for MEAD/USDC
    IJoePair public liquidityPair;

    struct BreweryStats {
        string name;                           // A unique string
        uint256 xp;                            // A XP value, increased on each claim
        uint256 productionRateMultiplier;      // The amount to increase yield by
        uint256 fermentationPeriodMultiplier;  // The amount to decrease the fermentation period by
        uint256 totalYield;                    // The total yield this brewery has produced
        uint256 lastTimeClaimed;               // The last time this brewery has had a claim
    }

    /// @notice The base yield that each Brewery earns
    uint256 public baseYield;

    /// @notice The 

    /// @notice A mapping of token ID to brewery stats
    mapping (uint256 => BreweryStats) public stats;

    /// @notice A list of tiers (index) and XP values (value), tiers.length = max tier.
    uint256[] public tiers;

    /// @notice A list of tiers (index) and yield bonuses (value), tiers.length = max tier
    uint256[] public yields;

    /// @notice The upper liquidity ratio (when to apply the higher discount)
    uint256 public liquidityRatio0 = 20;   // Liquidity ratio of 25%

    /// @notice The lower liquidity ratio (when to apply the lower discount)
    uint256 public liquidityRatio1 = 1;    // Liquidity ratio of 1%

    /// @notice The discount (to be applied when the liquidity ratio is equal to or above `liquidityRatio0`)
    uint256 public lpDiscount0 = 1;    // Discount of 1% for 25% or above

    /// @notice The discount (to be applied when the liquidity ratio is equal to or less than `liquidityRatio1`)
    uint256 public lpDiscount1 = 25;   // Discount of 25% for 1% or less

    constructor(address _meadTokenAddress, address _routerAddress, address _tavernsKeep, uint256 _initialSupply, uint256 _baseDailyYield, uint256 _baseFermentationPeriod) ERC721(NAME, SYMBOL) {
        tavernsKeep = _tavernsKeep;
        meadToken = IERC20(_meadTokenAddress);

        // Set up the router and the liquidity pair
        dexRouter = IJoeRouter02(_routerAddress);
        liquidityPair = IJoePair(IJoeFactory(dexRouter.factory()).getPair(_meadTokenAddress, USDC));
    }

    /**
     * @notice Mints a new tokenID, checking if the string name already exists
     */
    function mint(address _to, uint256 _tokenId, string memory _name) external onlyOwner {
        bytes32 strHash = keccak256(bytes(_name));
        _mint(_to, _tokenId);
        stats[_tokenId] = BreweryStats({
            name: _name, 
            xp: 0, 
            productionRateMultiplier: 100, 
            fermentationPeriodMultiplier: 100,
            totalYield: 0,
            lastTimeClaimed: block.timestamp
        });
    }

    function giveXP(uint256 _tokenId, uint256 _xp) external onlyOwner {
        stats[_tokenId].xp += _xp;
    }

    /**
     * @notice Claims the rewards
     */
    function claim(uint256 _tokenId) external {
        // TODO
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

    function buyNodeWithLP() external returns (uint256) {
        uint256 breweryPriceInUSDC = 100 * getUSDCForMead();
        uint256 breweryPriceInLP = getLPFromUSDC(breweryPriceInUSDC);
        liquidityPair.transfer(tavernsKeep, breweryPriceInLP * calculateLPDiscount());
    }

    /**
     * @notice Calculates the current LP discount
     */
    function calculateLPDiscount() public view returns (uint256) {
        (uint meadReserves, uint usdcReserves,) = liquidityPair.getReserves();
        uint256 fullyDilutedValue = getUSDCForMead() * meadToken.totalSupply();

        // If this is 5% its bad, if this is 20% its good
        uint256 liquidityRatio = usdcReserves / fullyDilutedValue;

        // X is liquidity ratio       (y0 = 5      y1 = 20)
        // Y is discount              (x0 = 15     x1 =  1)
        return (lpDiscount0 * (liquidityRatio1 - liquidityRatio) + lpDiscount1 * (liquidityRatio - liquidityRatio0)) / (liquidityRatio1 - liquidityRatio0);
    }

    /**
     * @notice Calculates how much USDC 1 LP token is worth
     */
    function getUSDCForOneLP() public view returns (uint256) {
        uint256 meadPrice = getUSDCForMead();
        uint256 lpSupply = liquidityPair.totalSupply();
        (uint meadReserves, uint usdcReserves,) = liquidityPair.getReserves();
        uint256 meadValue = meadReserves * meadPrice;
        uint256 usdcValue = usdcReserves;
        return (meadValue + usdcValue) / lpSupply;
    }

    /**
     * @notice Calculates how many LP tokens are worth `_amount` in USDC (for payment)
     */
    function getLPFromUSDC(uint256 _amount) public view returns (uint256) {
        return _amount * (1 / getUSDCForOneLP());
    }

    /**
     * @notice Returns how many MEAD tokens you get for 1 USDC
     */
    function getMeadforUSDC() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(meadToken);
        path[1] = USDC;
        uint256[] memory amountsOut = dexRouter.getAmountsIn(1e18, path);
        return amountsOut[0];
    }

    /**
     * @notice Returns how many USDC tokens you get for 1 MEAD
     */
    function getUSDCForMead() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = address(meadToken);
        uint256[] memory amountsOut = dexRouter.getAmountsIn(1e18, path);
        return amountsOut[0];
    }
}