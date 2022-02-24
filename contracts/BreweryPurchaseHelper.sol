pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ERC-721/Brewery.sol";

interface IxMEAD { 
    function redeem(address, uint256) external;
}
/**
 * @notice There are some conditions to make this work
 * 
 *  - Helper needs to be the owner of Brewery
 *  - Helper should be able to burn xMEAD
 * 
 */
contract BreweryPurchaseHelper is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice address of xMEAD
    address public xmead;

    /// @notice address for MEAD
    address public mead;

    /// @notice treasury for MEAD
    address public brewery;

    /// @notice Relevant events to emit
    event Redeemed(address account, uint256 amount);

    function initialize(address _xmead, address _mead, address _brewery) external initializer {
        xmead = _xmead;
        mead = _mead;
        brewery = _brewery;
    }

    function getPrice() public pure returns (uint256) {
        return 100 * 10 ** 18;
    }

    /**
     * @notice This function is called by the users
     */
    function purchaseWithMead(string memory name) public {
        IERC20Upgradeable(mead).safeTransferFrom(_msgSender(), address(this), getPrice());
        _mintBreweryTo(_msgSender(), name);
    }

    /**
     * @notice This function is called by the users
     */
    function purchaseWithxMead(string memory name) public {
        IxMEAD(xmead).redeem(_msgSender(), getPrice());
        _mintBreweryTo(_msgSender(), name);
    }

    function _mintBreweryTo(address account, string memory name) internal {
        uint256 tokenId = Brewery(brewery).totalSupply() + 1;
        Brewery(brewery).mint(account, tokenId, name);
    }
}