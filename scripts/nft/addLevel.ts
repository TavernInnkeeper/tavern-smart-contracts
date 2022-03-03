import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", "0x4C4a2f8c81640e47606d3fd77B353E87Ba015584")

    const nftID = "3";
    await Brewery.giveXP(nftID, ethers.utils.parseUnits("1000000", 18))
    await Brewery.claim(nftID);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
