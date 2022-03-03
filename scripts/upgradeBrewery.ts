import hre, { ethers, upgrades } from "hardhat";
import { deployContract, deployProxy } from "../helper/deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "./ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const BreweryFactory = await ethers.getContractFactory("Brewery");
    await upgrades.upgradeProxy("0x4C4a2f8c81640e47606d3fd77B353E87Ba015584", BreweryFactory)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
