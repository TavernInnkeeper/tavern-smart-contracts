import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { PRESALE_TESTNET } from "./ADDRESSES";

async function main() {

    let addresses = [
      '0xa18DC2e4126BA59c28ecf38563B11854735ff1Fb'
    ]

    const [deployer] = await ethers.getSigners();
    const presale = await ethers.getContractAt("WhitelistPresale", PRESALE_TESTNET)

    await presale.connect(deployer).addToWhitelist(addresses);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
