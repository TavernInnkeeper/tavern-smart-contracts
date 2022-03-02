pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoePair.sol";

import "./ERC-20/Mead.sol";
import "./ERC-20/xMead.sol";
import "./ERC-721/Brewery.sol";
import "./ClassManager.sol";
import "./xMeadRedeemHelper.sol";

/**
 * @notice There are some conditions to make this work
 * 
 *  - Helper needs to be the owner of Brewery
 *  - Helper should be able to burn xMEAD
 * 
 */
contract BreweryPurchaseHelper is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Used to give extra precision for percentages
    uint256 public constant PRECISION = 1e10;

    /// @notice The wallet address of the governing treasury
    address public tavernsKeep;

    /// @notice The wallet address of the rewards pool
    address public rewardsPool;

    /// @notice The fee that is given to treasuries
    uint256 public treasuryFee = 30 * PRECISION;

    /// @notice The fee that is given to rewards pool
    uint256 public rewardPoolFee = 70 * PRECISION;

    /// @notice address of xMEAD
    XMead public xmead;

    /// @notice address for MEAD
    Mead public mead;

    /// @notice address for MEAD
    ERC20Upgradeable public usdc;

    /// @notice treasury for MEAD
    Brewery public brewery;

    /// @notice The xMead redeemer
    xMeadRedeemHelper public redeemer;

    /// @notice The reputation manager
    ClassManager classManager;

    /// @notice The address of the dex router
    IJoeRouter02 public dexRouter;

    /// @notice The address of the pair for MEAD/USDC
    IJoePair public liquidityPair;

    /// @notice The amount of wallets that can be bought in one transaction
    uint256 public txLimit = 5;

    /// @notice The limit of the amount of BREWERYs per wallet
    uint256 public walletLimit = 100;

    /// @notice The cost of a BREWERY in MEAD tokens
    uint256 public breweryCost;

    /// @notice The cost of BREWERY in xMEAD tokens
    uint256 public xMeadCost;

    /// @notice Whether or not the USDC payments have been enabled (based on the treasury)
    bool public isUSDCEnabled;

    /// @notice Whether or not the LP payments have been enabled
    bool public isLPEnabled;

    /// @notice The amount of discount of USDC
    uint256 public usdcDiscount = 5 * PRECISION;
    
    /// @notice The upper liquidity ratio (when to apply the higher discount)
    uint256 public liquidityRatio0 = 20 * PRECISION;

    /// @notice The lower liquidity ratio (when to apply the lower discount)
    uint256 public liquidityRatio1 = 1 * PRECISION;

    /// @notice The discount (to be applied when the liquidity ratio is equal to or above `liquidityRatio0`)
    uint256 public lpDiscount0 = 1 * PRECISION;

    /// @notice The discount (to be applied when the liquidity ratio is equal to or less than `liquidityRatio1`)
    uint256 public lpDiscount1 = 25 * PRECISION;

    /// @notice The amount of reputation gained for buying a BREWERY with MEAD
    uint256 public reputationForMead;

    /// @notice The amount of reputation gained for buying a BREWERY with USDC
    uint256 public reputationForUSDC;

    /// @notice The amount of reputation gained for buying a BREWERY with LP tokens
    uint256 public reputationForLP;

    /// @notice Liquidity zapping slippage
    uint256 public zapSlippage = 10 * PRECISION;

    /// @notice The percentage fee for using the auto-zapping! 
    uint256 public zapFee = 1 * PRECISION;

    /// @notice Relevant events to emit
    event Redeemed(address account, uint256 amount);

    function initialize(address _xmead, address _mead, address _usdc, address _brewery, address _classManager) external initializer {
        xmead = XMead(_xmead);
        mead = Mead(_mead);
        usdc = ERC20Upgradeable(_usdc);
        brewery = Brewery(_brewery);
        classManager = ClassManager(_classManager);

        breweryCost = 100 * mead.decimals();
        xMeadCost   = 90 * xmead.decimals();
    }

    /**
     * ===========================================================
     *            INTERFACE
     * ============================================================
     */

    /**
     * @notice Handles the actual minting logic
     */
    function _mint(address account, string memory name, uint256 reputation) internal {
        require(brewery.balanceOf(msg.sender) <= walletLimit, "Cant go over limit");
        uint256 tokenId = Brewery(brewery).totalSupply() + 1;
        Brewery(brewery).mint(account, tokenId, name);
        classManager.addReputation(msg.sender, reputation);
    }

    /**
     * @notice Purchases a BREWERY using MEAD
     */
    function purchaseWithXMead(string memory name) external {

        uint256 xMeadAmount = xMeadCost * getUSDCForMead() * xmead.decimals();
        redeemer.redeem(xMeadAmount);
        mead.transferFrom(msg.sender, tavernsKeep, xMeadAmount * treasuryFee / (100 * PRECISION));
        mead.transferFrom(msg.sender, rewardsPool, xMeadAmount * rewardPoolFee / (100 * PRECISION));

        // Mint logic
        _mint(msg.sender, name, reputationForMead);
    }
    
    /**
     * @notice Purchases a BREWERY using MEAD
     */
    function purchaseWithMead(string memory name) external {
        uint256 meadAmount = breweryCost * getUSDCForMead() * mead.decimals();
        mead.transferFrom(msg.sender, tavernsKeep, meadAmount * treasuryFee / (100 * PRECISION));
        mead.transferFrom(msg.sender, rewardsPool, meadAmount * rewardPoolFee / (100 * PRECISION));

        // Mint logic
        _mint(msg.sender, name, reputationForMead);
    }

    /**
     * @notice Purchases a BREWERY using USDC
     */
    function purchaseWithUSDC(string memory name) external {
        require(isUSDCEnabled, "USDC discount off");

        // Take payment for USDC tokens
        uint256 usdcAmount = breweryCost * getUSDCForMead() * (100 - usdcDiscount) / (100 * PRECISION);
        usdc.transferFrom(msg.sender, tavernsKeep, usdcAmount);

        // Mint logic
        _mint(msg.sender, name, reputationForMead);
    }
    
    /**
     * @notice Purchases a BREWERY using LP tokens
     */
    function purchaseWithLP(string memory name) external {
        require(isLPEnabled, "USDC discount off");

        // Take payment in MEAD-USDC LP tokens
        uint256 discount = calculateLPDiscount();
        require(discount <= lpDiscount0, "LP discount off");
        uint256 breweryPriceInUSDC = breweryCost * getUSDCForMead();
        uint256 breweryPriceInLP = getLPFromUSDC(breweryPriceInUSDC);
        liquidityPair.transferFrom(msg.sender, tavernsKeep, breweryPriceInLP * ((100 * PRECISION - discount) / (100 * PRECISION)));

        // Mint logic
        _mint(msg.sender, name, reputationForMead);
    }

    /**
     * @notice Purchases a BREWERY using USDC and automatically converting into LP tokens 
     */
    function purchaseWithLPUsingZap(string memory name) external {
        uint256 discount = calculateLPDiscount();
        uint256 discountMultiplier = ((100 * PRECISION - discount) / (100 * PRECISION));
        uint256 zapFeeMultiplier = (100 * PRECISION + zapFee) / (100 * PRECISION);

        // Get the price of a brewery as if it were valued at the LP tokens rate + a fee for automatically zapping for you
        // Bear in mind this will still be discounted even though we take an extra fee!
        uint256 breweryPriceInUSDCWithLPDiscount = breweryCost * getUSDCForMead() * discountMultiplier * zapFeeMultiplier;

        /// @notice Handles the zapping of liquitity for us + an extra fee
        /// @dev The LP tokens will now be in the hands of the msg.sender
        uint256 liquidityTokens = zapLiquidity(breweryPriceInUSDCWithLPDiscount * (100 * PRECISION + zapFee) / (100 * PRECISION));

        // Send the tokens from the account transacting this function to the taverns keep
        liquidityPair.transferFrom(msg.sender, tavernsKeep, liquidityTokens);

        // Mint logic
        _mint(msg.sender, name, reputationForMead);
    }

    /**
     * @notice Takes an amount of USDC and zaps it into liquidity
     * @dev User must have an approved MEAD and USDC allowance on this contract
     * @return The liquidity token balance
     */
    function zapLiquidity(uint256 usdcAmount) public returns (uint256) {
        uint256 half = usdcAmount / 2;

        address[] memory path = new address[](2);
        path[0] = address(mead);
        path[1] = address(usdc);

        // Swap any USDC to receive 50 MEAD
        uint[] memory amounts = dexRouter.swapExactTokensForTokens(
            half, 
            0, 
            path,
            msg.sender,
            block.timestamp + 120
        );

        // Transfer the tokens into the contract
        mead.transferFrom(msg.sender, address(this), amounts[0]);
        usdc.transferFrom(msg.sender, address(this), amounts[1]);

        // Approve the router to spend these tokens 
        mead.approve(address(dexRouter), amounts[0]);
        usdc.approve(address(dexRouter), amounts[1]);

        // Add liquidity (MEAD + USDC) to receive LP tokens
        (, , uint liquidity) = dexRouter.addLiquidity(
            address(mead),
            address(usdc),
            amounts[0],
            amounts[1],
            amounts[0] * (100 * PRECISION - zapSlippage),
            amounts[1] * (100 * PRECISION - zapSlippage),
            msg.sender,
            block.timestamp + 120
        );

        return liquidity;
    }

    /**
     * @notice Calculates the current LP discount
     */
    function calculateLPDiscount() public view returns (uint256) {
        (, uint usdcReserves,) = liquidityPair.getReserves();
        uint256 fullyDilutedValue = getUSDCForMead() * mead.totalSupply();

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
        path[0] = address(mead);
        path[1] = address(usdc);
        uint256[] memory amountsOut = dexRouter.getAmountsIn(10 ** usdc.decimals(), path);
        return amountsOut[0];
    }

    /**
     * @notice Returns how many USDC tokens you get for 1 MEAD
     */
    function getUSDCForMead() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(mead);
        uint256[] memory amountsOut = dexRouter.getAmountsIn(10 ** mead.decimals(), path);
        return amountsOut[0];
    }

    /**
     * ===========================================================
     *            ADMIN FUNCTIONS
     * ============================================================
     */
    function setTreasuryAddress(address _treasury) external onlyOwner {
        tavernsKeep = _treasury;
    }
    
    function setRewardsPool(address _rewardsPool) external onlyOwner {
        rewardsPool = _rewardsPool;
    }

    function setTreasuryFee(uint256 _fee) external onlyOwner {
        treasuryFee = _fee * PRECISION;
    }

    function setRewardsFee(uint256 _fee) external onlyOwner {
        rewardPoolFee = _fee * PRECISION;
    }

    function setTransactionLimit(uint256 _limit) external onlyOwner {
        txLimit = _limit;
    }

    function setWalletLimit(uint256 _limit) external onlyOwner {
        walletLimit = _limit;
    }

    function setBreweryCost(uint256 _cost) external onlyOwner {
        breweryCost = _cost;
    }

    function setXMeadCost(uint256 _cost) external onlyOwner {
        xMeadCost = _cost;
    }

    function setUSDCEnabled(bool _b) external onlyOwner {
        isUSDCEnabled = _b;
    }

    function setLPEnabled(bool _b) external onlyOwner {
        isLPEnabled = _b;
    }

    function setUSDCDiscount(uint256 _discount) external onlyOwner {
        usdcDiscount = _discount * PRECISION;
    }

    function setMinLiquidityDiscount(uint256 _discount) external onlyOwner {
        lpDiscount0 = _discount * PRECISION;
    }

    function setMaxLiquidityDiscount(uint256 _discount) external onlyOwner {
        lpDiscount1 = _discount * PRECISION;
    }

    function setMinLiquidityRatio(uint256 _ratio) external onlyOwner {
        liquidityRatio1 = _ratio * PRECISION;
    }

    function setMaxLiquidityRatio(uint256 _ratio) external onlyOwner {
        liquidityRatio0 = _ratio * PRECISION;
    }

    function setReputationForMead(uint256 _reputation) external onlyOwner {
        reputationForMead = _reputation;
    }

    function setReputationForUSDC(uint256 _reputation) external onlyOwner {
        reputationForUSDC = _reputation;
    }

    function setReputationForLP(uint256 _reputation) external onlyOwner {
        reputationForLP = _reputation;
    }

    function setZapSlippage(uint256 _zap) external onlyOwner {
        zapSlippage = _zap;
    }
}