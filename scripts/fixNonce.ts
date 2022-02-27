import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { PRESALE_MAINNET } from "./ADDRESSES";
import { readFileSync } from "fs";

async function main() {

    const [deployer] = await ethers.getSigners();


    let gasPrice = await ethers.getDefaultProvider().getGasPrice()
    console.log(ethers.utils.formatUnits(gasPrice, 'gwei'));
    let nonce = 25;
    for(let i = 0; i < 5; ++i) {
      let tx = await deployer.sendTransaction({to: deployer.address, value: 0, gasPrice: gasPrice.mul(4), gasLimit: 21000, nonce: nonce++});
      let result = await tx.wait();
    }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });