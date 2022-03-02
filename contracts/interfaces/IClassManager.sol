pragma solidity ^0.8.4;

interface IClassManager {
    function getClass(address _account) external view returns (uint32);

    function getReputation(address _account) external view returns (uint256);
}