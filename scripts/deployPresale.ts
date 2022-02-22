import { Contract } from "ethers";
import hre, { ethers, upgrades } from "hardhat";
import { BifrostSale01, BifrostSettings, BifrostRouter01, CustomToken } from "../typechain";
import { Ierc20Extended } from "../typechain/Ierc20Extended";
import { deployContract, deployProxy } from "./deployer";

import PROXY_ADMIN_ABI from './ProxyAdmin.json'
import CONFIG_JSON from "./config.json";

const config: {[index: string]:any} = CONFIG_JSON;


const DAY_SECONDS = 86400;
const HOUR_SECONDS = 3600;

// Be sure of this admin
// This admin contract address can be found in ".openzeppelin" folder
const proxyAdmin = "0x8f44c5DeE2E961A26bBF93fCE55e176377bf9F6B";

async function deployBifrostContracts() {

  // Settings
  //  0x10ED43C718714eb63d5aA57B78B54704E256024E  (PcS V2 Mainnet)
  //  0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  (PcS V2 Testnet)
  let pancakeRouter          = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';
  let listingFee             = ethers.utils.parseUnits("25", 16);                // The flat fee in BNB (25e16 = 0.25 BNB)
  let launchingFee           = 100;                                             // The percentage of fees returned to the router owner for successful sales (100 = 1%)
  let minLiquidityPercentage = 5000;                                            // The minimum liquidity percentage (5000 = 50%)
  let minCapRatio            = 5000;                                            // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
  let minUnlockTimeSeconds   = 30 * DAY_SECONDS;                                    // The minimum amount of time before liquidity can be unlocked
  let minSaleTime            = 1 * HOUR_SECONDS;                                     // The minimum amount of time a sale has to run for
  let maxSaleTime            = 0;                   
  let earlyWithdrawPenalty   = 2000;                                            // 20%

  const saleImpl = await deployContract("BifrostSale01");
  const whitelistImpl = await deployContract("Whitelist");
  const settings = <BifrostSettings>await deployProxy("BifrostSettings", pancakeRouter, proxyAdmin, saleImpl.address, whitelistImpl.address);
  const router = <BifrostRouter01>await deployProxy("BifrostRouter01", settings.address);

  console.log("Router (Proxy):", router.address);
  console.log("Settings (Proxy):", settings.address);
  console.log("Sale Impl:", saleImpl.address);
  console.log("Whitelist:", whitelistImpl.address);

  await settings.setBifrostRouter(router.address);
  await settings.setListingFee(listingFee)
  await settings.setLaunchingFee(launchingFee)
  await settings.setMinimumLiquidityPercentage(minLiquidityPercentage)
  await settings.setMinimumCapRatio(minCapRatio)
  await settings.setMinimumUnlockTime(minUnlockTimeSeconds)
  await settings.setMinimumSaleTime(minSaleTime)
  await settings.setEarlyWithdrawPenalty(earlyWithdrawPenalty)

  // TODO: Exclude router from fee
}

async function setProxyAdmin() {
  const settings = "";
  const proxyAdmin = "";

  const contract = <BifrostSettings>await ethers.getContractAt("BifrostSettings", "");
  await contract.setProxyAdmin(proxyAdmin);
}

async function upgradeRouterContract() {
  const routerFactory = await ethers.getContractFactory("BifrostRouter01");
  await upgrades.upgradeProxy("0x39d6AEB87E54686f46729bDE8bFE145163E3F06F", routerFactory);
}

async function upgradeSaleContract(sale: string) {
    const saleFactory = await ethers.getContractFactory("BifrostSale01");
    await upgrades.upgradeProxy(sale, saleFactory);
}

async function deploySaleImplementation() {
  const saleImpl = await deployContract("BifrostSale01");
  console.log("Sale Implementation", saleImpl.address);
}

async function main() {

  /**
   * Initialize, getting the correct settings 
   */
  // const chainId: any  = await hre.getChainId();
  // console.log("Chain:", chainId);
  // const proxyAdmin = config[chainId].proxyAdmin;
  // const routerProxy = config[chainId].router;
  // const settingsProxy = config[chainId].settings;
  // console.log("Proxy Admin:", proxyAdmin);
  // console.log("Router (Proxy):", routerProxy);
  // console.log("Settings (Proxy):", settingsProxy);

  /**
   * Create a new token
   */
  // const rewardToken = <CustomToken>await deployContract("CustomToken", "TEST", "TEST", ethers.utils.parseUnits("10000000000", 18));
  // console.log("Address", rewardToken.address);
  // await rewardToken.transfer("0x1bA1d0F472f44c8f41f65CA10AB43A038969DF57", ethers.utils.parseUnits("10000000000", 18));

  /**
   * Deploy a new bifrost contract
   */
  //await deployBifrostContracts();

  /**
   * Upgrade an existing bifrost router
   */
  const routerFactory = await ethers.getContractFactory("BifrostRouter01");
  await upgrades.upgradeProxy("0x0E73B8A050E814719D2a0BAD9EA500dB3B53A54B", routerFactory);

  /**
   * Upgrade a sale contract
   */
  // const saleToUpgrade = '0xa8f6006236Cb1458571ef3B88CdC6A5F3a9dEEC1';
  // const saleImpl = await deployContract("BifrostSale01");
  // console.log("New Sale (Implementation)", saleImpl.address);
  // const proxyAdminContract = await ethers.getContractAt(PROXY_ADMIN_ABI, proxyAdmin);
  // await proxyAdminContract.upgrade(saleToUpgrade, saleImpl.address);
  // let settingsAddress = "0x1E78E815b4B0Ca9c74B8217E8FCE90977B4ea03d";
  // const settings = <BifrostSettings>await ethers.getContractAt("BifrostSettings", settingsAddress)
  // await settings.setSaleImpl(saleImpl.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
