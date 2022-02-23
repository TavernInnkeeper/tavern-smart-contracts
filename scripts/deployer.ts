import { Contract } from "ethers";
import hre, { ethers, upgrades } from "hardhat";

async function deployProxy(name: string, ...constructorArgs: any[]) : Promise<Contract> {
    const factory = await ethers.getContractFactory(name);
    const contract = await upgrades.deployProxy(factory, constructorArgs);
    await contract.deployed();
    return contract;
}

async function deployContract(name: string, ...constructorArgs: any[]) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy(...constructorArgs);
  await contract.deployed();
  return contract;
}

export {
    deployContract,
    deployProxy,
}