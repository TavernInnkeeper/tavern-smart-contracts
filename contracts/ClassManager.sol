pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @notice Handles all the logic for reputation and classes for particular accounts
 */
contract ClassManager is Initializable, AccessControlUpgradeable {

    /// @notice The structs defining details that are associated with each address
    /// @dev class = 0 is Novice, they then start at 1
    struct Brewer {
        uint32  class;
        uint256 reputation;
    }

    /// @notice The reputation thresholds for each class, where index is equal to the class
    /// @dev classThresholds[0] is always 0
    /// @dev classThresholds.length == how many classes there are
    uint256[] public classThresholds;

    /// @notice A mapping of accounts to their reputations
    mapping (address => Brewer) public brewers;

    /// @notice
    event ClassChanged(address account, uint256 reputation, uint32 class);

    /// @notice The specific role to give to contracts so they can manage the brewers reputation of accounts
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "Incorrect role!");
        _;
    }

    function initialize() external initializer {
        __Context_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Called after every change in reputation to an account
     * @dev Emits an event if there is a class change
     */
    function _handleChange(address _account) internal {
        uint32 nextClass = 0;
        for (uint32 i = 0; i < classThresholds.length - 1; ++i) {
            if (brewers[_account].reputation >= classThresholds[i]) {
                nextClass = i;
            } else {
                break;
            }
        }
        
        // If there was a change in this brewers class, then we emit an event for the blockchain to see the class change.
        if (brewers[_account].class != nextClass) {
            emit ClassChanged(_account, brewers[_account].reputation, nextClass);
        }

        brewers[_account].class = nextClass;
    }

    function addReputation(address _account, uint256 _amount) external isRole(MANAGER_ROLE) {
        brewers[_account].reputation += _amount;
        _handleChange(_account);
    }

    function removeReputation(address _account, uint256 _amount) external isRole(MANAGER_ROLE) {
        brewers[_account].reputation -= _amount;
        _handleChange(_account);
    }

    function clearReputation(address _account) external isRole(MANAGER_ROLE) {
        brewers[_account].reputation = 0;
        _handleChange(_account);
    }

    function getClass(address _account) external view returns (uint32) {
        return brewers[_account].class;
    }

    function getReputation(address _account) external view returns (uint256) {
        return brewers[_account].reputation;
    }
}