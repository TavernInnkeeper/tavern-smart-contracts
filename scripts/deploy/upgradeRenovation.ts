import { ethers, upgrades } from "hardhat";
import { renovation_address } from "../NFT_ADDRESSES";

async function main() {
  const factory = await ethers.getContractFactory("Renovation");
  await upgrades.upgradeProxy(renovation_address, factory);
  console.log("Upgraded renovation!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
