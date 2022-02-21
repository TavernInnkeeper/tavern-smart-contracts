pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";

/**
 * @notice The inert receipt token for the presale, this gives The Tavern protocol flexibility and control over how this is handled
 */
contract xMead is Ownable, AccessControl {
    
    /// @notice Token Info
    string private constant NAME     = "xMead";
    string private constant SYMBOL   = "xMEAD";
    uint8  private constant DECIMALS = 18;

    /// @notice The current amount of xMEAD that exists right now
    uint256 private _totalSupply;

    /// @notice The xMEAD balances
    mapping(address => uint256) private balances;

    /// @notice The total amount of xMEAD that has historically been issued
    uint256 private _totalIssued;

    /// @notice Relevant events to emit
    event Issued(address account, uint256 amount);
    event Redeemed(address account, uint256 amount);

    /// @notice The specific role to give to the private sale contract so it can issue xMEAD
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    
    /// @notice The specific role to give to the helper contracts to let users redeem their xMEAD
    bytes32 public constant REDEEMER_ROLE = keccak256("REDEEMER_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "Incorrect role!");
        _;
    }

    /**
     * @notice The constructor of the xMEAD token
     */
    constructor() {
        _totalIssued = 0;
        _totalSupply = 0;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Mints and issues a user an amount of xMEAD
     */
    function issue(address account, uint256 amount) public isRole(ISSUER_ROLE) {
        require(account != address(0), "Cannot issue to zero address");

        _totalIssued += amount;
        _totalSupply += amount;
        balances[account] += amount;

        emit Issued(account, amount);
    }

    /**
     * @notice This function is called by the Redeemer contract
     */
    function redeem(address account, uint256 amount) public isRole(REDEEMER_ROLE) {
        require(account != address(0), "Cannot issue to zero address");
        require(balances[account] >= amount, "Insufficent balance");

        balances[account] -= amount;
        _totalSupply -= amount;

        emit Redeemed(account, amount);
    }

    /**
     * @notice xMEAD token is inert, and so it cannot be transfered - only redeemed!
     */
    function transfer(address, uint256) external pure returns (bool) {
        // Do nothing!
        revert("Inert token!");
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint256) {
        return DECIMALS;
    }

    function issuedAmount() public view returns (uint256) {
        return _totalIssued;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}