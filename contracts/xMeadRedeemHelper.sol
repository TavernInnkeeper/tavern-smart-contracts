pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IxMEAD { 
    function redeem(address, uint256) external;
}

contract xMeadRedeemHelper is Initializable, AccessControlUpgradeable {
    /// @notice address of xMEAD
    address public xMEAD;

    /// @notice address for MEAD
    address public MEAD;

    /// @notice treasury for MEAD
    address public pool;

    /// @notice Flag to enable redeem
    bool public redeemEnabled;

    /// @notice The limtis imposed on each account
    mapping (address => uint256) limits;

    /// @notice The unlock timer
    uint256 public unlockTimer;

    /// @notice Relevant events to emit
    event Redeemed(address account, uint256 amount);

    /// @notice The specific role to give to contracts so they can manage the brewers reputation of accounts
    bytes32 public constant BYPASS_ROLE = keccak256("BYPASS_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Incorrect role!");
        _;
    }

    function initialize(address _xMEAD, address _MEAD, address _pool) external initializer {
        xMEAD = _xMEAD;
        MEAD = _MEAD;
        pool = _pool;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Sets the treasury address
     */
    function setPool(address _pool) external isRole(DEFAULT_ADMIN_ROLE) {
        pool = _pool;
    }

    /**
     * @notice Pause or release redeem
     */
    function enableRedeem(bool _redeemEnabled) external isRole(DEFAULT_ADMIN_ROLE) {
        redeemEnabled = _redeemEnabled;
    }

    /**
     * @notice This function is called by the users
     * @dev If user/contract has BYPASS_ROLE they are able to bypass the limits
     */
    function redeem(uint256 amount) external isRole(BYPASS_ROLE) {
        require(redeemEnabled, "redeem is paused or not started");
        IxMEAD(xMEAD).redeem(msg.sender, amount);
        IERC20Upgradeable(MEAD).transferFrom(pool, msg.sender, amount);
    }
}