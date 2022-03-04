import hre, { ethers, upgrades } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { dateString, sleep } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";
import { writeFileSync } from "fs";
import { Brewery_address, ClassManager_address, Mead_address, renovation_address, settings_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    // Dependants: address _routerAddress, address _usdcAddress, address _tavernsKeep, uint256 _initialSupply
    const Mead = await ethers.getContractFactory("Mead");
    await upgrades.upgradeProxy(Mead_address, Mead);

    const ClassManager = await ethers.getContractFactory("ClassManager");
    await upgrades.upgradeProxy(ClassManager_address, ClassManager);

    const Settings = await ethers.getContractFactory("TavernSettings");
    await upgrades.upgradeProxy(settings_address, Settings);
    
    const Brewery = await ethers.getContractFactory("Brewery");
    await upgrades.upgradeProxy(Brewery_address, Brewery);
    
    const Renovation = await ethers.getContractFactory("Renovation");
    await upgrades.upgradeProxy(renovation_address, Renovation);

    console.log("Upgraded!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
