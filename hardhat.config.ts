import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "@typechain/hardhat"
import "hardhat-contract-sizer";
import "solidity-coverage";
import "hardhat-abi-exporter";

import { config as dotEnvConfig } from "dotenv";

dotEnvConfig();

const mnemonic = process.env.WORKER_SEED || "";
const privateKey = process.env.PRIVATE_KEY || "";
const privateKey2 = process.env.PRIVATE_KEY || "";

const defaultConfig = {
  accounts: { mnemonic },
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      forking: {
        url: 'https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/avalanche/mainnet',
      },
    },
    bscmainnet: {
      url: "https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/bsc/mainnet",
      accounts: [privateKey, privateKey2]
    },
    bsctestnet: {
      url: "https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/bsc/testnet",
      accounts: [privateKey, privateKey2],
      allowUnlimitedContractSize: true
    },
    avaxmainnet: {
      url: 'https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/avalanche/mainnet',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    avaxtestnet: {
      url: 'https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/avalanche/testnet',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    }
  },
  abiExporter: {
    path: './data/abi',
    runOnCompile: true,
    clear: true,
    flat: false,
    spacing: 2,
    pretty: false,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  typechain: {
    outDir: './typechain',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
};

export default config;