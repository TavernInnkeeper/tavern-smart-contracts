import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { PRESALE_MAINNET, PRESALE_TESTNET, USDC_MAINNET, XMEAD_MAINNET } from "./ADDRESSES";

async function main() {

    const [deployer] = await ethers.getSigners();
    const presale = await ethers.getContractAt("WhitelistPresale", PRESALE_MAINNET)

    const USDC = await ethers.getContractAt(ERC20, USDC_MAINNET);
    const usdcDecimals = await USDC.decimals();

    // Get Xmead contract
    const xMead = await ethers.getContractAt("XMead", XMEAD_MAINNET);

    let tx = await presale.connect(deployer).withdraw(USDC.address);
    await tx.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
