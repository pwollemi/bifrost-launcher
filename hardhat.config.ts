import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-typechain";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "solidity-coverage";
import "hardhat-abi-exporter";

import { config as dotEnvConfig } from "dotenv";

dotEnvConfig();

const mnemonic = process.env.WORKER_SEED || "";
const mnemonic2 = process.env.RAINBOW_DEPLOY || "";
const mnemonic3 = process.env.RAINBOW_TREASURY || "";
const mnemonic4 = process.env.BIFROST_DEPLOY || "";

const defaultConfig = {
  accounts: { mnemonic, mnemonic2, mnemonic3, mnemonic4 },
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
    mainnet: {
      url: "https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/bsc/mainnet",
      chainId: 56,
      ...defaultConfig
    },
    testnet: {
      url: "https://speedy-nodes-nyc.moralis.io/50561c02c5a853febf23eb96/bsc/testnet",
      chainId: 97,
      ...defaultConfig
    },
    hardhat: {
      forking: {
        url:
          "https://data-seed-prebsc-1-s1.binance.org:8545",
      },
      accounts: {
        accountsBalance: "10000000000000000000000",
      },
      chainId: 1337,
    },
  },
  abiExporter: {
    path: './data/abi',
    clear: true,
    flat: true,
    spacing: 0,
    pretty: false,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  }
};

export default config;