import hre, { ethers } from "hardhat";
import { PRESALE_TESTNET, XMEAD_TESTNET } from "./ADDRESSES";

async function main() {
  // The signers
  const [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();

  const presale = await ethers.getContractAt("WhitelistPresale", PRESALE_TESTNET);
  const xMead = await ethers.getContractAt("XMead", XMEAD_TESTNET);

  // Let the presale contract issue xMEAD
  await xMead.connect(deployer).grantRole(await xMead.ISSUER_ROLE(), presale.address);
  console.log(`Presale contract (${presale.address}) is enabled to issue xMead!`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
