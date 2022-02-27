import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";
import { USDC_MAINNET, XMEAD_MAINNET, XMEAD_TESTNET } from "../ADDRESSES";

async function main() {
  // The signers
  const [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();

  // Get USDC Contract
  const USDC = await ethers.getContractAt(ERC20, USDC_MAINNET);
  const usdcDecimals = await USDC.decimals();

  // Get Xmead contract
  const xMead = await ethers.getContractAt("XMead", XMEAD_MAINNET);

  // Deploy presale
  const presale = await deployProxy("WhitelistPresale", xMead.address, USDC_MAINNET);
  console.log("Whitelisted Presale", presale.address);

  // Configure and run presale
  const raiseAim     = '360000';  // USDC
  const tokenRate    = '1.11';    // xMEAD (per $1 USDC)
  const min          = '100';     // USDC
  const max          = '1000';    // USDC
  const intervals    = '2';       // 2 intervals (max, then max*2)
  const timeInterval = 3600;      // 1 hour (In seconds)

  await presale.connect(deployer).configure(
    ethers.utils.parseUnits(raiseAim, usdcDecimals), 
    ethers.utils.parseUnits(tokenRate, await xMead.decimals()), 
    ethers.utils.parseUnits(min, usdcDecimals),
    ethers.utils.parseUnits(max, usdcDecimals),
    intervals,
    timeInterval
  );
  // await presale.connect(deployer).addToWhitelist([signer.address]);
  // await presale.connect(deployer).start();
  console.log(`Presale contract (${presale.address}) is configured!`);
  console.log(`Raising: $${raiseAim}      Min Contr: $${min}      xMEAD per $1: ${tokenRate}`);

  // Let the presale contract issue xMEAD
  await xMead.connect(deployer).grantRole(await xMead.ISSUER_ROLE(), presale.address);
  console.log(`Presale contract (${presale.address}) is enabled to issue xMead!`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
