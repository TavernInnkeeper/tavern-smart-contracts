import { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import { dateString } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";
import { writeFileSync } from "fs";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    // Settings
    const routerAddress       = TRADERJOE_ROUTER_MAINNET;
    const usdcAddress         = USDC_MAINNET;
    const tavernsKeep         = deployer.address;
    const initialSupply       = ethers.utils.parseUnits("1000000", 18);    // 1,000,000
    const fermentationPeriod  = (14 * 86400).toString();                   //         14 days in seconds
    const experiencePerSecond = "1";                                       //         2

    // Dependants: 
    const xMead = await deployContract("XMead");
    console.log("xMead", xMead.address);

    // Dependants: address _routerAddress, address _usdcAddress, address _tavernsKeep, uint256 _initialSupply
    const Mead = await deployProxy("Mead", routerAddress, usdcAddress, tavernsKeep, initialSupply);
    console.log("Mead", Mead.address);

    // Dependants: 
    const ClassManager = await deployProxy("ClassManager", ["0", "50", "500", "2500"]);
    console.log("ClassManager", ClassManager.address);

    // Dependants: 
    //   address _xmead, 
    //   address _mead, 
    //   address _usdc, 
    //   address _classManager,
    //   address _routerAddress
    const taxes = ['1800', '1600', '1400', '1200']; // 18%, 16%, 14%, 12%
    const settings = await deployProxy("TavernSettings", xMead.address, Mead.address, usdcAddress, ClassManager.address, routerAddress, taxes);
    console.log("Settings", settings.address);

    // Configure settings
    await settings.setTavernsKeep(deployer.address);
    await settings.setRewardsPool(deployer.address);
    await settings.setTreasuryFee(ethers.utils.parseUnits("30", 2));
    await settings.setRewardPoolFee(ethers.utils.parseUnits("70", 2));
    await settings.setTxLimit("5");
    await settings.setWalletLimit("20");
    await settings.setBreweryCost(ethers.utils.parseUnits("100", 18));
    await settings.setXMeadCost(ethers.utils.parseUnits("90", 18));

    // Dependants:
    //   address _tavernSettings,
    //   uint256 _fermentationPeriod,
    //   uint256 _experiencePerSecond
    const Brewery = await deployProxy("Brewery", settings.address, fermentationPeriod, experiencePerSecond);
    console.log("Brewery", Brewery.address);

    // Configure brewery
    await Brewery.setBaseURI("https://ipfs.tavern.money/ipfs/QmSJDwZxDArzBkZPxPjswj7ZYzx8KUEX1Do9cbnSaSwzm5")
    await Brewery.setTokenURI(0, 0, "/type/0/tier/0.json")
    await Brewery.setTokenURI(0, 1, "/type/0/tier/1.json")
    await Brewery.setTokenURI(0, 2, "/type/0/tier/2.json")
    await Brewery.setTokenURI(4, 0, "/type/4/tier/0.json")
    await Brewery.setTokenURI(4, 1, "/type/4/tier/1.json")
    await Brewery.setTokenURI(4, 2, "/type/4/tier/2.json")
    await Brewery.addTier("0", ethers.utils.parseUnits("2", await Mead.decimals()));
    await Brewery.addTier("50", ethers.utils.parseUnits("3", await Mead.decimals()));
    await Brewery.addTier("100", ethers.utils.parseUnits("4", await Mead.decimals()));

    // Setup renovation
    const Renovation = await deployProxy("Renovation", Brewery.address);
    console.log("Renovation: ", Renovation.address);
    await settings.setRenovationAddress(Renovation.address);

    // Mint our first brewery (id: 1)
    await Brewery.mint(deployer.address, "TestNFT!");
    console.log("Minted!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
