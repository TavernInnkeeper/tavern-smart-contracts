import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "../../helper/deployer";

import ERC20 from '../../abis/ERC20.json';
import { sleep } from "../../helper/utils";

async function main() {
  // The signers
  const [deployer, addr1, addr2, addr3, addr4] = await ethers.getSigners();

  // Get USDC Contract
  const USDCProxyAddressMainnet = '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';
  const USDCProxyAddressTestnet = '0x5425890298aed601595a70AB815c96711a31Bc65';

  // Get USDC Contract
  const USDC = await ethers.getContractAt(ERC20, USDCProxyAddressTestnet);
  const usdcDecimals = await USDC.decimals();

  // Get Xmead contract
  const xMeadAddress = "0x31eC5033605c1B368BF207e22E829f7E4335fbf5";
  const xMead = await ethers.getContractAt("XMead", xMeadAddress);

  // Deploy presale
  const presale = await deployProxy("WhitelistPresale", xMead.address, USDCProxyAddressTestnet);
  console.log("Whitelisted Presale", presale.address);

  // Configure and run presale
  const raiseAim     = '80000';  // USDC
  const tokenRate    = '1.11';    // xMEAD (per $1 USDC)
  const min          = '100';     // USDC
  const max          = '10000';    // USDC
  const intervals    = '2';       // 2 intervals (max, then max*2)
  const timeInterval = 900;       // 15 minutes (In seconds)

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
