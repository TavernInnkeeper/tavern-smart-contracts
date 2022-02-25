import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { PRESALE_TESTNET } from "./ADDRESSES";

async function main() {

    const [deployer] = await ethers.getSigners();
    const presale = await ethers.getContractAt("WhitelistPresale", PRESALE_TESTNET)

    let tx = await presale.connect(deployer).start();
    await tx.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
