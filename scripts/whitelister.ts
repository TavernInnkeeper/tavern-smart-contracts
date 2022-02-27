import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { PRESALE_MAINNET } from "./ADDRESSES";
import { readFileSync } from "fs";

async function main() {


    // let addresses = [
    //   '0xa18DC2e4126BA59c28ecf38563B11854735ff1Fb'
    // ]
    
    let whitelist = [
      '0xD28ECF09E36fB2E5ACb13a0f8a4167ab9132d294',
      '0xb332B8025ED9f8Fc50b73a121dFDf4FF745903F7',
      '0xaCfABe248B6a067c7A2973CdD676b1Fb10308Bd7',
      '0x3533af5322185c913eD09Ef81E998E0C49f819Cb',
      '0x6361d5b55F8078cB1DE84FBF4b3476A8a0E73e31'
    ]

    for (let i = 0; i < whitelist.length; ++i) {
      whitelist[i] = ethers.utils.getAddress(whitelist[i]);
    }

    const [deployer] = await ethers.getSigners();

    const presale = await ethers.getContractAt("WhitelistPresale", PRESALE_MAINNET);
    await presale.connect(deployer).addToWhitelist(whitelist);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
