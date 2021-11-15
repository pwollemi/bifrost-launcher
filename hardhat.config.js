const { task } = require("hardhat/config");
const fs = require('fs');

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require('hardhat-abi-exporter');

const getValue = async (method) => {
    let r = null;
    await method.call().then(function (ret) {
        r = ret;
    });
    return r;
}

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs) => {
    const account = web3.utils.toChecksumAddress(taskArgs.account);
    const balance = await web3.eth.getBalance(account);

    console.log(web3.utils.fromWei(balance, "ether"), "ETH");
});

task("balanceOf", "Prints an account's token balance")
    .addParam("account", "The account's address")
    .addParam("token", "The ERC20 token address")
    .addParam("contractname", "The ERC20 token contract name")
    .setAction(async (taskArgs) => {
        const Token = new web3.eth.Contract(JSON.parse(fs.readFileSync('data/abi/' + taskArgs.contractname + ".json")), taskArgs.token);
        let balance = await getValue(Token.methods.balanceOf(taskArgs.account));
        console.log(balance);
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
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
  }
};
