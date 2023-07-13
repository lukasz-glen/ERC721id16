const fs = require('fs');
const path = require('path');
require('hardhat-ignore-warnings');
require('@nomiclabs/hardhat-truffle5');
for (const f of fs.readdirSync(path.join(__dirname, 'hardhat'))) {
  require(path.join(__dirname, 'hardhat', f));
}
require('hardhat-gas-reporter');

module.exports = {
  solidity: {
    version: '0.8.13',
    settings: {
      optimizer: {
        runs: 10000,
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 10000000,
    },
  },
  gasReporter: {
    showMethodSig: true,
    currency: 'USD',
  },
};
