import { ethers } from "hardhat";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)
    await Brewery.setTradingEnabled(true);
    console.log("Enabled!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
