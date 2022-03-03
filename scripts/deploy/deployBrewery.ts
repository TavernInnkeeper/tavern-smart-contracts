import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    // Settings
    const routerAddress       = TRADERJOE_ROUTER_MAINNET;
    const usdcAddress         = USDC_MAINNET;
    const tavernsKeep         = deployer.address;
    const initialSupply       = ethers.utils.parseUnits("1000000", 18);    // 1,000,000
    const dailyYield          = ethers.utils.parseUnits("2", 18);          //         2
    const fermentationPeriod  = (14 * 86400).toString();                   //         14 days in seconds
    const experiencePerSecond = "1";                                       //         2

    // Dependants: 
    const xMead = await deployContract("XMead");
    console.log("xMead", xMead.address);

    // Dependants: address _routerAddress, address _usdcAddress, address _tavernsKeep, uint256 _initialSupply
    const Mead = await deployProxy("Mead", routerAddress, usdcAddress, tavernsKeep, initialSupply);
    console.log("Mead", Mead.address);

    // Dependants: 
    const ClassManager = await deployProxy("ClassManager");
    console.log("ClassManager", ClassManager.address);

    // Dependants: 
    //   address _xmead, 
    //   address _mead, 
    //   address _usdc, 
    //   address _classManager,
    //   address _routerAddress
    const settings = await deployProxy("TavernSettings", xMead.address, Mead.address, usdcAddress, ClassManager.address, routerAddress);
    console.log("settings", settings.address);

    // Configure settings
    await settings.setTavernsKeep(deployer.address);
    await settings.setRewardsPool(deployer.address);
    await settings.setTreasuryFee(ethers.utils.parseUnits("30", 10));
    await settings.setRewardPoolFee(ethers.utils.parseUnits("70", 10));
    await settings.setTxLimit("5");
    await settings.setWalletLimit("20");
    await settings.setBreweryCost(ethers.utils.parseUnits("100", 18));
    await settings.setXMeadCost(ethers.utils.parseUnits("90", 18));

    // Dependants:
    //   address _tavernSettings,
    //   uint256 _baseDailyYield,
    //   uint256 _baseFermentationPeriod,
    //   uint256 _baseExperiencePerSecond
    const Brewery = await deployProxy("Brewery", settings.address, dailyYield, fermentationPeriod, experiencePerSecond);
    console.log("Brewery", Brewery.address);

    // Configure brewery
    await Brewery.setBaseURI("https://ipfs.tavern.money/ipfs/QmaRVcZcZNZaYrCNg3QUbnu55cFSnpKXrGqPRwUJh87z9z")
    await Brewery.setTokenURI(0, 0, "/type/0/tier/0.json")
    await Brewery.setTokenURI(0, 1, "/type/0/tier/1.json")
    await Brewery.setTokenURI(0, 2, "/type/0/tier/2.json")
    await Brewery.addTier("0", ethers.utils.parseUnits("2", await Mead.decimals()));
    await Brewery.addTier("50", ethers.utils.parseUnits("3", await Mead.decimals()));
    await Brewery.addTier("100", ethers.utils.parseUnits("4", await Mead.decimals()));

    await Brewery.mint(deployer.address, "TestNFT!");
    console.log("Minted!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
