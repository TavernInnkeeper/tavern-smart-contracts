import hre, { ethers } from "hardhat";
import { deployContract } from "../../helper/deployer";

async function main() {

  // Deploy xMEAD
  const xMead = await deployContract("XMead");
  console.log("xmead address", xMead.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
