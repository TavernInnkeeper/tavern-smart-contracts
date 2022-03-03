

import { ethers } from "hardhat";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)

    await Brewery.setBaseExperiencePerSecond("1");
    await Brewery.clearTiers();
    await Brewery.addTier("0", ethers.utils.parseUnits("2", 18));
    await Brewery.addTier("50", ethers.utils.parseUnits("3", 18));
    await Brewery.addTier("100", ethers.utils.parseUnits("4", 18));

    console.log("Configured!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
