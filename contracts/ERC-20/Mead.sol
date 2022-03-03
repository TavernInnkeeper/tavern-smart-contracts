pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";


/**
 * @notice The connective tissue of the Tavern.money ecosystem
 */
contract Mead is Initializable, IERC20Upgradeable, OwnableUpgradeable {
    
    /// @notice Token Info
    string private constant NAME     = "Mead";
    string private constant SYMBOL   = "MEAD";
    uint8  private constant DECIMALS = 18;

    /// @notice Token balances
    mapping(address => uint256) private _balances;

    /// @notice The token allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice The total supply that is currently in circulation
    uint256 private _totalSupply;

    /// @notice The address of the dex router
    IJoeRouter02 public dexRouter;

    /// @notice The address of the pair for MEAD/USDC
    address public liquidityPair;

    /// @notice The address of the governing treasury
    address public tavernsKeep;

    /// @notice Whether or not trading is enabled (can only be set to true)
    bool public isTradingEnabled;

    /// @notice The buy tax imposed on transfers from the liquidity pair (Unused unless necessary)
    uint256 public buyTax;

    /// @notice The sell tax imposed on transfers to the liquidity pair (Starts at 25%, and slowly goes down to 8%)
    uint256 public sellTax;

    /// @notice The addresses that are excluded from trading
    mapping(address => bool) public blacklist;

    /// @notice The addresses that are excluded from paying fees
    mapping(address => bool) public whitelist;

    /**
     * @notice The constructor of the MEAD token
     */
    function initialize(address _routerAddress, address _usdcAddress, address _tavernsKeep, uint256 _initialSupply) external initializer {
        __Ownable_init();

        //
        isTradingEnabled = false;
        buyTax = 0;
        sellTax = 25;

        // Treasury address
        tavernsKeep = _tavernsKeep;

        // Set up the router and the liquidity pair
        dexRouter = IJoeRouter02(_routerAddress);
        liquidityPair = IJoeFactory(dexRouter.factory()).createPair(address(this), _usdcAddress);

        // Mint the initial supply to the deployer
        _mint(msg.sender, _initialSupply * 10**DECIMALS);
    }

    /**
     * ==============================================================
     *             Admin Functions
     * ==============================================================
     */

    /**
     * @notice Withdraws stuck ERC-20 tokens from the contract
     */
    function withdrawToken(address _token) external payable onlyOwner {
        IERC20Upgradeable(_token).transfer(owner(), IERC20Upgradeable(_token).balanceOf(address(this)));
    }

    /**
     * @notice Enables or disables whether an account pays tax
     */
    function setWhitelist(address _account, bool _value) external onlyOwner {
        whitelist[_account] = _value;
    }

    /**
     * @notice Enables or disables whether an account can trade MEAD
     */
    function setBlacklist(address _account, bool _value) external onlyOwner {
        blacklist[_account] = _value;
    }

    /**
     * @notice Sets the buy tax
     * @dev Tax restriction hardcoded to not go above 25%
     */
    function setBuyTax(uint256 _tax) external onlyOwner {
        require(_tax <= 25, "Tax cant be higher than 25");
        buyTax = _tax;
    }

    /**
     * @notice Sets the sell tax
     * @dev Tax restriction hardcoded to not go above 25%
     */
    function setSellTax(uint256 _tax) external onlyOwner {
        require(_tax <= 25, "Tax cant be higher than 25");
        sellTax = _tax;
    }

    /**
     * @notice Used to enable trading
     */
    function enableTrading() public onlyOwner {
        require(!isTradingEnabled, "Trading already enabled");
        isTradingEnabled = true;
    }

    /**
     * @notice Mints token to the treasury address
     */
    function mint(uint256 _amount) public onlyOwner {
        _mint(msg.sender, _amount * 10**DECIMALS);
    }

    /**
     * @notice Burns tokens from the treasury address
     */
    function burn(uint256 _amount) public onlyOwner {
        _burn(msg.sender, _amount * 10**DECIMALS);
    }

    /**
     * ==============================================================
     *             Usability Functions
     * ==============================================================
     */

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "Sender is zero address");
        require(to != address(0), "Recipient is zero address");
        require(isTradingEnabled, "Cannot trade yet!");
        require(!blacklist[from] && !blacklist[to], "Address blacklisted");

        // Whether or not we are taking a fee
        bool takeFee = !(whitelist[from] || whitelist[to]);
        uint256 fee = 0;

        // If we are taking a fee, and transfering to (i.e. selling) the liquidity pool, then use the sell tax
        // If we are taking a fee, and transfering from (i.e. buying) the liquidity pool, then use the buy tax
        // Otherwise do a direct transfer
        if (takeFee && to == liquidityPair) {
            fee = sellTax;
        } else if (takeFee && from == liquidityPair) {
            fee = buyTax;
        } else {
            fee = 0;
        }

        _tokenTransfer(from, to, amount, fee);
    }

    /**
     * @notice Handles the actual token transfer
     */
    function _tokenTransfer(address _from, address _to, uint256 _amount, uint256 _fee) internal {
        require(_balances[_from] >= _amount, "Not enough tokens");

        (uint256 transferAmount, uint256 feeAmount) = _getTokenValues(_amount, _fee);

        _balances[_from] = _balances[_from] - _amount;
        _balances[_to] += transferAmount;
        _balances[tavernsKeep] += feeAmount;

        emit Transfer(_from, _to, transferAmount);
    }

    /**
     * @notice Grabs the respective components of a taxed transfer
     */
    function _getTokenValues(uint256 _amount, uint256 _fee) private pure returns (uint256, uint256) {
        uint256 feeAmount = _amount * _fee / 100;
        uint256 transferAmount = _amount - feeAmount;
        return (transferAmount, _fee);
    }

    /**
     * ==============================================================
     *             ERC-20 Default funcs
     * ==============================================================
     */

    function name() external view virtual returns (string memory) {
        return NAME;
    }

    function symbol() external view virtual returns (string memory) {
        return SYMBOL;
    }

    function decimals() external view virtual returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}