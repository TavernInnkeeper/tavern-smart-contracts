import hre, { ethers, upgrades } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { PREMINT_FORKED_MAINNET, PRESALE_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";

async function main() {
  // The signers
  const [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();
  
  const factory = await ethers.getContractFactory("Premint");
  await upgrades.upgradeProxy(PREMINT_FORKED_MAINNET, factory);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
