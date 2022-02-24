import hre, { ethers } from "hardhat";
import { deployContract, deployProxy } from "./deployer";

import ERC20 from '../abis/ERC20.json';
import { sleep } from "./utils";

async function main() {

  // Deploy xMEAD
  const xMead = await deployContract("XMead");
  console.log("xmead address", xMead.address);

  // Deploy presale
  const presale = await deployProxy("WhitelistPresale", xMead.address);
  console.log("presale", presale.address);

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x1bA1d0F472f44c8f41f65CA10AB43A038969DF57"],
  });

  // Get signers
  const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
  const signer = await ethers.getSigner("0x1bA1d0F472f44c8f41f65CA10AB43A038969DF57");
  console.log("Avax Balance", ethers.utils.formatEther(await signer.getBalance()));

  // USDC
  const USDCProxyAddress = '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';
  const USDC = await ethers.getContractAt(ERC20, USDCProxyAddress);
  await USDC.connect(signer).approve(presale.address, ethers.constants.MaxUint256);
  const usdcDecimals = await USDC.decimals();
  console.log("Signer approved the presale to spend its USDC!")

  // Configure and run presale
  const raiseAim = '10';
  const tokenRate = 100;
  const min = '1';
  const max = '2';
  const intervals = '2';
  const timeInterval = 10;
  await presale.connect(owner).configure(
    ethers.utils.parseUnits(raiseAim, usdcDecimals), 
    ethers.utils.parseUnits(tokenRate, await xMead.decimals()), 
    ethers.utils.parseUnits(min, usdcDecimals),
    ethers.utils.parseUnits(max, usdcDecimals),
    intervals,
    timeInterval
  );
  await presale.connect(owner).addToWhitelist([signer.address]);
  await presale.connect(owner).start();
  console.log("Presale configured, signer added to whitelist, and presale started!");
  console.log(`Raising: $${raiseAim}      Min Contr: $${min}      xMEAD per $1: ${tokenRate}`);

  // Owner configure
  await xMead.connect(owner).grantRole(await xMead.ISSUER_ROLE(), presale.address);
  console.log("Owner has set the presale to being able to issue xMEAD to indivduals");


  // Signer tried to invest $52
  await presale.connect(signer).invest(ethers.utils.parseUnits('2', usdcDecimals));
  console.log("Signer invested first $2");

  //await presale.connect(signer).invest(ethers.utils.parseUnits('2', usdcDecimals));
  //console.log("Signer invested second $2");

  await sleep(10000);

  await presale.connect(signer).invest(ethers.utils.parseUnits('2', usdcDecimals));
  console.log("Signer invested last $2");

  // What is the current status 
  let balance = await xMead.balanceOf(signer.address);
  console.log("Signer now has ", ethers.utils.formatUnits(balance, await xMead.decimals()))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
