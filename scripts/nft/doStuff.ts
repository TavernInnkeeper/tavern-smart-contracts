import { ethers } from "hardhat";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer, alice, bob] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)
    await Brewery.transferFrom(deployer.address, alice.address, "1");
    console.log("Transfered!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
