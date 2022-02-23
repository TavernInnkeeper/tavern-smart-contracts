import { Contract } from "ethers";
import hre, { ethers } from "hardhat";

import ERC20 from '../abis/ERC20.json';

async function deployContract(name: string, ...constructorArgs: any[]) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployed();
  return contract;
}

async function main() {

  // Deploy xMEAD
  const xMead = await deployContract("XMead");
  console.log("xmead address", xMead.address);

  // Deploy presale
  const presale = await deployContract("WhitelistPresale", xMead.address);
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
  const USDCImplAddress = '0xa3fa3d254bf6af295b5b22cc6730b04144314890';
  const USDC = await ethers.getContractAt(ERC20, USDCImplAddress);
  await USDC.connect(signer).approve(presale.address, ethers.constants.MaxUint256);
  console.log("Approved!")

  // Configure and run presale
  const raiseAim = ethers.utils.parseUnits('10', 6);
  const tokenRate = 100;
  const min = ethers.utils.parseUnits('1', 6);
  const timeInterval = 10;
  await presale.connect(owner).configure(raiseAim, tokenRate, min, timeInterval);
  await presale.connect(owner).addToWhitelist([signer.address]);
  await presale.connect(owner).start();

  await presale.connect(signer).invest(ethers.utils.parseUnits('5', 6));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
