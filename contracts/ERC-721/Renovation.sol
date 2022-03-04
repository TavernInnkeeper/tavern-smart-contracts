pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Renovation is Initializable, AccessControlUpgradeable, ERC721EnumerableUpgradeable {

    uint256 public constant PRODUCTION_RATE = 0;
    uint256 public constant FERMENTATION_PERIOD = 1;
    uint256 public constant EXPERIENCE_BOOST = 2;
    uint256 public constant TYPE_CHANGE = 3;
    uint256 public constant NAME_CHANGE = 4;

    struct RenovationValues {
        uint256 renovationType;
        uint256 intValue;
        string strValue;
    }

    mapping(uint256 => RenovationValues) renovations;

    /// @notice The specific role to give to things so they can create Renovations
    bytes32 public constant CREATOR_ROLE = keccak256("MINTER_ROLE");

    /// @notice The specific role to give to things so they can consume Renovations
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    /// @notice Modifier to test that the caller has a specific role (interface to AccessControl)
    modifier isRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Incorrect role!");
        _;
    }

    function initialize(address _brewery) external initializer {
        __AccessControl_init();
        __ERC721_init("Renovation", "Reno");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(CONSUMER_ROLE, msg.sender);
        _grantRole(CONSUMER_ROLE, _brewery);
    }

    /**
     * @dev Unused, specified to suppress compiler error for duplicates function from multiple parents
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function create(address to, uint256 _type, uint256 intValue, string memory strValue) external isRole(CREATOR_ROLE) returns(uint256) {
        uint256 id = totalSupply() + 1;
        _safeMint(to, id);

        renovations[id].renovationType = _type;
        renovations[id].intValue = intValue;
        renovations[id].strValue = strValue;

        return id;
    }

    /**
     * @notice Uses the current renovation
     */
    function consume(uint256 _renovationId) external isRole(CONSUMER_ROLE) {
        //require(msg.sender == ownerOf(_renovationId), "Not owner");
        _burn(_renovationId);
    }

    function getType(uint256 _renovationId) external view returns(uint256) {
        return renovations[_renovationId].renovationType;
    }

    function getIntValue(uint256 _renovationId) external view returns(uint256) {
        return renovations[_renovationId].intValue;
    }

    function getStrValue(uint256 _renovationId) external view returns(string memory) {
        return renovations[_renovationId].strValue;
    }
}