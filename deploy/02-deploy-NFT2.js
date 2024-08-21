const { ethers, network } = require("hardhat");
const { verify } = require("../utils/verify.js");

developmentChain = ["localhost", "hardhat", "ganache"];

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  let NFTtoken2;
  let args;

  log("--------------------------------------------------");
  log(`1. Deploying Token1 ..................... `);
  NFTtoken2 = await deploy("NFTToken2", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (
      !developmentChain.includes(network.name)
  ) {
      await verify(NFTtoken2.address, args);
  }

  log("--------------------------------------------------");
  log("Token1 deployed at: " + (await NFTtoken2.address));
  log("--------------------------------------------------");
};

module.exports.tags = ["Token1", "all"];
