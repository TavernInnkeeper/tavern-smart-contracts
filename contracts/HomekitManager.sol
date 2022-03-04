pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./ERC-721/Renovation.sol";
import "./TavernSettings.sol";
import "./interfaces/IClassManager.sol";

/**
 * @notice Homekit manager is a smart contract that allows users to purchase small, less efficient BREWERYs at fixed prices
 *        
 *        A homekit is always worth $100 in MEAD, and they always produce $0.30 worth of MEAD a day.
 *        Homekits can be converted into BREWERYs based on the face value. Take an example where MEAD is $10 each:
 *            A brewery will cost 100 MEAD which is $1,000
 *            So you'd need 10 homekits to convert into a BREWERY
 */
contract HonmekitManager is Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    /// @notice The data contract containing all of the necessary settings
    TavernSettings public settings;

    /// @notice HOMEKITs can't earn before this time
    uint256 public startTime;

    struct HomekitStats {
        uint256 count;             // How many are owned
        uint256 totalYield;        // The total yield this brewery has produced
        uint256 lastTimeClaimed;   // The last time this brewery has had a claim
    }

    /// @notice A mapping of how many homekits each person has
    mapping (address => uint256) public owned;

    /// @notice The base production rate in seconds
    uint256 public productionRatePerSecond;

    /// @notice Emitted events
    event Claim(address indexed owner, uint256 tokenId, uint256 amount, uint256 timestamp);
    event LevelUp(address indexed owner, uint256 tokenId, uint256 tier, uint256 xp, uint256 timestamp);

    /// @notice The specific role to give to smart contracts or wallets that will be allowed to create
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Incorrect role!");
        _;
    }

    function initialize(
        address _tavernSettings,
        uint256 _price,
        uint256 _yield
    ) external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);

        settings = TavernSettings(_tavernSettings);
    }


}