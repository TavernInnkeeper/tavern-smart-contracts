import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { PRESALE_MAINNET, PRESALE_TESTNET, USDC_MAINNET, USDC_TESTNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";
import { Brewery_address, xMead_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const breweryAddress = Brewery_address;
    const xMeadAddress = xMead_address;
    const usdcAddress = USDC_MAINNET;
    const whitelistPresaleAddress = PRESALE_MAINNET;

    const USDC = await ethers.getContractAt(ERC20, usdcAddress);
    const usdcDecimals = await USDC.decimals();

    const whitelistLimit = '10';

    // Deploy the premint contract
    const Premint = await deployProxy("Premint", breweryAddress, xMeadAddress, usdcAddress, whitelistPresaleAddress);
    await Premint.addBatch('2000', 100 * 10**usdcDecimals);
    await Premint.addBatch('1600', 100 * 10**usdcDecimals);
    await Premint.addBatch('1200', 100 * 10**usdcDecimals);
    await Premint.addBatch('800', 100 * 10**usdcDecimals);
    await Premint.addBatch('400', 100 * 10**usdcDecimals);
    await Premint.setWhitelistBatch('3600', whitelistLimit);

    console.log("Premint contract deployed!", Premint.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
