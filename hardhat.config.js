require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-ethers");
require("hardhat-contract-sizer");
require('hardhat-abi-exporter');

const fs = require('fs')
const getSecret = (secretKey, defaultValue='') => {
    const SECRETS_FILE = "./secrets.js"
    let secret = defaultValue
    if (fs.existsSync(SECRETS_FILE)) {
        const { secrets } = require(SECRETS_FILE)
        if (secrets[secretKey]) { secret = secrets[secretKey] }
    }

    return secret
}

const iotexUrlTestnet = () => {
  return `https://babel-api.testnet.iotex.io`
}

const iotexUrlMainnet = () => {
  return `https://babel-api.mainnet.iotex.io`
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.6.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20,
      },
    },
  },
  networks: {
    iotexTestnet: {
        url: iotexUrlTestnet(),
        gas: 10000000,  // tx gas limit
        accounts: [getSecret('IOTEX_DEPLOYER_PRIVATEKEY')]
    },
    iotexMainnet: {
        url: iotexUrlMainnet(),
        gas: 10000000,  // tx gas limit
        accounts: [getSecret('IOTEX_DEPLOYER_PRIVATEKEY')]
    },
},
abiExporter: {
}
};
