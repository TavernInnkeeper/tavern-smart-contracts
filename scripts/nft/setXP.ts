import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    // Settings
    const routerAddress       = TRADERJOE_ROUTER_MAINNET;
    const usdcAddress         = USDC_MAINNET;
    const tavernsKeep         = deployer.address;
    const initialSupply       = ethers.utils.parseUnits("1000000", 18); // 1,000,000
    const dailyYield          = ethers.utils.parseUnits("2", 18);          //         2
    const fermentationPeriod  = ethers.utils.parseUnits("2", 18);          //         2
    const experiencePerSecond = ethers.utils.parseUnits("2", 18);          //         2

    // Dependants:
    //   address _tavernSettings,
    //   uint256 _baseDailyYield,
    //   uint256 _baseFermentationPeriod,
    //   uint256 _baseExperiencePerSecond
    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)
    
    // await Brewery.addTier("0", "20");
    // await Brewery.addTier("1", "40");
    // await Brewery.addTier("2", "60");
    console.log("tier", (await Brewery.getTier("1")).toString());
    
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
