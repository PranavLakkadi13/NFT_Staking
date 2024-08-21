const { ethers, network } = require("hardhat");
const { verify } = require("../utils/verify.js");

developmentChain = ["localhost", "hardhat", "ganache"];

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  let token;
  let args;

  log("--------------------------------------------------");
  log(`1. Deploying Token1 ..................... `);
  token = await deploy("RewardToken", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (
      !developmentChain.includes(network.name)
  ) {
      await verify(token.address, args);
  }

  log("--------------------------------------------------");
  log("Token1 deployed at: " + (await token.address));
  log("--------------------------------------------------");
};

module.exports.tags = ["Token", "all"];
