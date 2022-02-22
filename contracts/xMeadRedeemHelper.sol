pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IxMEAD { 
    function redeem(address, uint256) external;
}

contract xMeadRedeemHelper is Initializable, OwnableUpgradeable {
    /// @notice address of xMEAD
    address public xMEAD;

    /// @notice address for MEAD
    address public MEAD;

    /// @notice treasury for MEAD
    address public treasury;

    /// @notice Flag to enable redeem
    bool public redeemEnabled;

    /// @notice Relevant events to emit
    event Redeemed(address account, uint256 amount);

    function initialize(address _xMEAD, address _MEAD, address _treasury) external initializer {
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
     * @notice Pause or release redeem
     */
    function enableRedeem(bool _redeemEnabled) external onlyOwner {
        redeemEnabled = _redeemEnabled;
    }

    /**
     * @notice This function is called by the users
     */
    function redeem(uint256 amount) public {
        require(redeemEnabled, "redeem is paused or not started");
        IxMEAD(xMEAD).redeem(msg.sender, amount);
        IERC20Upgradeable(MEAD).transferFrom(treasury, msg.sender, amount);
    }
}