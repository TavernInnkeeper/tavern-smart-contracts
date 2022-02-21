pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Renovation is Ownable, ERC721 {

    uint256 public constant PRODUCTION_RATE = 0;
    uint256 public constant FERMENTATION_PERIOD = 1;
    uint256 public constant EXPERIENCE_BOOST = 2;
    uint256 public constant SKIN_CHANGE = 3;
    uint256 public constant NAME_CHANGE = 4;

    struct RenovationValues {
        uint256 renovationType;
        uint256 intValue;
        string strValue;
    }

    mapping(uint256 => RenovationValues) values;

    constructor() {
    }

    /**
     * @notice Uses the current renovation
     */
    function consume(uint256 _renovationId) external {
        require(msg.sender == ownerOf(_renovationId), "Not owner");
        _burn(_renovationId);
    }

    function getType(uint256 _renovationId) external view returns(uint256) {
        return values[_renovationId].renovationType;
    }

    function getIntValue(uint256 _renovationId) external view returns(uint256) {
        return values[_renovationId].intValue;
    }

    function getStrValue(uint256 _renovationId) external view returns(string memory) {
        return values[_renovationId].strValue;
    }
}