import { ethers, upgrades } from "hardhat";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
  const factory = await ethers.getContractFactory("Brewery");
  await upgrades.upgradeProxy(Brewery_address, factory);
  console.log("Upgraded!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
