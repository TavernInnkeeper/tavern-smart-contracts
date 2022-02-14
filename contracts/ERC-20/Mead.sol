pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice The connective tissue of the Tavern.money ecosystem
 */
contract Mead is ERC20 {
    /// @notice The address of the governing treasury
    address public tavernsKeep;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _tavernsKeep
    ) ERC20(name, symbol) {
        tavernsKeep = _tavernsKeep;
        _mint(tavernsKeep, initialSupply * 1e18);
    }

    /**
     * @notice Mints token to the treasury address
     */
    function mint(uint256 _amount) public {
        require(
            msg.sender == tavernsKeep,
            "Not treasury"
        );
        _mint(msg.sender, _amount * 1e18);
    }

    /**
     * @notice Burns tokens from the treasury address
     */
    function burn(uint256 _amount) public {
        require(
            msg.sender == tavernsKeep,
            "Not treasury"
        );
        _burn(msg.sender, _amount * 1e18);
    }
}