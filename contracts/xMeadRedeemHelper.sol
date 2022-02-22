pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IxMEAD { 
    function redeem(address, uint256) external;
}

contract xMeadRedeemHelper is Ownable {
    /// @notice address of xMEAD
    address public xMEAD;

    /// @notice address for MEAD
    address public MEAD;

    /// @notice treasury for MEAD
    address public treasury;

    /// @notice Relevant events to emit
    event Redeemed(address account, uint256 amount);

    constructor(address _xMEAD, address _MEAD, address _treasury) {
        xMEAD = _xMEAD;
        MEAD = _MEAD;
        treasury = _treasury;
    }

    /**
     * @notice Sets the treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /**
     * @notice This function is called by the users
     */
    function redeem(uint256 amount) public {
        IxMEAD(xMEAD).redeem(msg.sender, amount);
        IERC20(MEAD).transferFrom(treasury, msg.sender, amount);
    }
}