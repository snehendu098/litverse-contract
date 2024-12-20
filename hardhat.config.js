require("@matterlabs/hardhat-zksync-solc");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  zksolc: {
    version: "1.3.9",
    compilerSource: "binary",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  networks: {
    bnb_testnet: {
      url: "https://97.rpc.thirdweb.com/9IrLWEC5ucScgoe2zSMbEJSl4qmmXSnUYtS8Yw9y8sxRzcXrntVdl_fLF2lUbGHDsoEicNJNBGHAbhxvWFjvEw",
      ethNetwork: "testnet",
      chainId: 97,
      zksync: true,
    },
  },
  paths: {
    artifacts: "./artifacts-zk",
    cache: "./cache-zk",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
};
