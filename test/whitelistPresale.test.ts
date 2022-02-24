/* eslint-disable no-await-in-loop */
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { setNextBlockTimestamp, getLatestBlockTimestamp, mineBlock, latest, impersonateForToken } from "../helper/utils";
import { deployContract, deployProxy } from "../helper/deployer";
import { IERC20, WhitelistPresale, XMead } from "../typechain";

chai.use(solidity);
const { expect } = chai;

const USDC = {
  address: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
  holder: "0xbf14db80d9275fb721383a77c00ae180fc40ae98",
  decimals: 6,
  symbol: "USDC",
}

const routerAddress = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";
const tavernsKeep = ethers.constants.AddressZero; // templates
const initialSupply = ethers.utils.parseUnits("100000000", 18);

describe('Public Presale', () => {
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let deployer: SignerWithAddress;

  let whitelistPresale: WhitelistPresale;
  let xMead: XMead;
  let usdc: IERC20;

  const raiseAim = ethers.utils.parseUnits("100000", 6);
  const tokenRate = 100; // 100 xMEAD per 1 USDC
  const min = ethers.utils.parseUnits("100", 6)
  const timeInterval = 900; // 15 mins

  const max = 2000;

  before(async () => {
    [deployer, alice, bob] = await ethers.getSigners();
    usdc = <IERC20>await ethers.getContractAt("IERC20", USDC.address);
    xMead = <XMead>await deployContract("XMead");

    await impersonateForToken(USDC, deployer, "10000000");
    await usdc.transfer(alice.address, ethers.utils.parseUnits("1000000", USDC.decimals));
    await usdc.transfer(bob.address, ethers.utils.parseUnits("1000000", USDC.decimals));
  });

  beforeEach(async () => {
    whitelistPresale = <WhitelistPresale>await deployProxy("WhitelistPresale", xMead.address);
    await xMead.grantRole(await xMead.ISSUER_ROLE(), whitelistPresale.address);
    await whitelistPresale.configure(raiseAim, tokenRate, min, max, 5, timeInterval);
    await whitelistPresale.addToWhitelist([deployer.address]);
  });

  it("configure", async () => {
    expect(await whitelistPresale.raiseAim()).to.be.equal(raiseAim);
    expect(await whitelistPresale.tokenRate()).to.be.equal(tokenRate);
    expect(await whitelistPresale.min()).to.be.equal(min);
    expect(await whitelistPresale.timeInterval()).to.be.equal(timeInterval);
  });

  it("start", async () => {
    await whitelistPresale.start();
    expect(await whitelistPresale.isRunning()).to.be.equal(true);
  });

  it("max contribution", async() => {
    await whitelistPresale.start()
    const startTime = await getLatestBlockTimestamp();
    
    // 0 - 15 min
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits(max.toString(), USDC.decimals));

    // 15 - 30 min
    await setNextBlockTimestamp(startTime + timeInterval);
    await mineBlock();
    expect(await whitelistPresale.getInterval()).to.be.equal(1);
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits((max * 2).toString(), USDC.decimals));

    // 30 - 45 min
    await setNextBlockTimestamp(startTime + timeInterval * 2);
    await mineBlock();
    expect(await whitelistPresale.getInterval()).to.be.equal(2);
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits((max * 3).toString(), USDC.decimals));

    // 45 - 60 min
    await setNextBlockTimestamp(startTime + timeInterval * 3);
    await mineBlock();
    expect(await whitelistPresale.getInterval()).to.be.equal(3);
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits((max * 4).toString(), USDC.decimals));

    // 60+ min
    await setNextBlockTimestamp(startTime + timeInterval * 4);
    await mineBlock();
    expect(await whitelistPresale.getInterval()).to.be.equal(4);
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits("10000", USDC.decimals));

    await setNextBlockTimestamp(startTime + timeInterval * 10);
    await mineBlock();
    expect(await whitelistPresale.getMaxContribution()).to.be.equal(ethers.utils.parseUnits("10000", USDC.decimals));
  });

  describe("invest", async () => {
    it("can't invest before start", async () => {
      await expect(whitelistPresale.invest(1)).to.be.revertedWith("Presale not running");
    });

    it("must be whitelisted", async () => {
      await whitelistPresale.start();
      await expect(whitelistPresale.connect(alice).invest(1)).to.be.revertedWith("User not whitelisted");
    });

    it("can't exceed raiseAim", async () => {
      await whitelistPresale.start();
      await expect(whitelistPresale.invest(raiseAim.add(1))).to.be.revertedWith("Exceeded raise aim");
    });

    it("can't deposit more than max", async () => {
      await whitelistPresale.start();
      const max = await whitelistPresale.getMaxContribution();
      await expect(whitelistPresale.invest(max.add(1))).to.be.revertedWith("Cant deposit more than max");
    });

    it("can't deposit less than min", async () => {
      await whitelistPresale.start();
      await expect(whitelistPresale.invest(min.sub(1))).to.be.revertedWith("Cant deposit less than min");
    });

    it("invest", async () => {
      await whitelistPresale.addToWhitelist([alice.address]);
      await whitelistPresale.start();
      const startTime = await getLatestBlockTimestamp();
      const investAmount = ethers.utils.parseUnits("10000", USDC.decimals);
      const xmeadAmount = investAmount.mul(tokenRate).mul(1e12);
      await setNextBlockTimestamp(startTime + 864000);

      const usdc0 = await usdc.balanceOf(alice.address);
      const xmead0 = await xMead.balanceOf(alice.address);
      await usdc.connect(alice).approve(whitelistPresale.address, ethers.constants.MaxUint256);
      await whitelistPresale.connect(alice).invest(investAmount);
      const usdc1 = await usdc.balanceOf(alice.address);
      const xmead1 = await xMead.balanceOf(alice.address);

      expect(await whitelistPresale.participants()).to.be.equal(1);
      expect(await whitelistPresale.totalDeposited()).to.be.equal(investAmount);
      expect(usdc0.sub(usdc1)).to.be.equal(investAmount);
      expect(xmead1.sub(xmead0)).to.be.equal(xmeadAmount);
    });
  })

  it("withdraw", async () => {
    await whitelistPresale.addToWhitelist([alice.address]);
    await whitelistPresale.start();
    const startTime = await getLatestBlockTimestamp();
    const investAmount = ethers.utils.parseUnits("10000", USDC.decimals);
    await setNextBlockTimestamp(startTime + 864000);

    await usdc.connect(alice).approve(whitelistPresale.address, ethers.constants.MaxUint256);
    await whitelistPresale.connect(alice).invest(investAmount);

    const usdc0 = await usdc.balanceOf(deployer.address);
    await whitelistPresale.withdraw(usdc.address);
    const usdc1 = await usdc.balanceOf(deployer.address);

    expect(usdc1.sub(usdc0)).to.be.equal(investAmount);
  });
});
