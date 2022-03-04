import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { TRADERJOE_ROUTER_MAINNET, USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)
    
    await Brewery.setBaseURI("https://ipfs.tavern.money/ipfs/QmSJDwZxDArzBkZPxPjswj7ZYzx8KUEX1Do9cbnSaSwzm5")

    // Default
    await Brewery.setTokenURI(0, 0, "/type/0/tier/0.json")
    await Brewery.setTokenURI(0, 1, "/type/0/tier/1.json")
    await Brewery.setTokenURI(0, 2, "/type/0/tier/2.json")

    // Magic
    await Brewery.setTokenURI(4, 0, "/type/4/tier/0.json")
    await Brewery.setTokenURI(4, 1, "/type/4/tier/1.json")
    await Brewery.setTokenURI(4, 2, "/type/4/tier/2.json")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
