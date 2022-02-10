import 'dotenv/config';
import {HardhatUserConfig} from 'hardhat/types';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-gas-reporter';
import {accounts, etherscanApiKey} from './utils/networks';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: accounts('localhost'),
    },
    localhost: {
      url: 'http://localhost:8545',
      accounts: accounts('localhost'),
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org',
      accounts: accounts('bsc'),
      chainId: 56,
      live: true,
    },
    matic: {
      url: 'https://rpc-mainnet.maticvigil.com/v1/a50eb5139e4cb2ce865cf47c1b664985eb69b86e',
      accounts: accounts('matic'),
      chainId: 137,
      live: true,
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 5,
    enabled: !!process.env.REPORT_GAS,
  },
  etherscan: {
    apiKey: etherscanApiKey(),
  },
  namedAccounts: {
    creatorpoly: 1,
    creator: 2,
  },
};

export default config;
