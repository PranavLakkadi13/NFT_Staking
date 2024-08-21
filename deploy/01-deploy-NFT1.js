const { ethers, network } = require("hardhat");
const { verify } = require("../utils/verify.js");

developmentChain = ["localhost", "hardhat", "ganache"];

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  let NFTtoken;
  let args;

  log("--------------------------------------------------");
  log(`1. Deploying Token1 ..................... `);
  NFTtoken = await deploy("NFTToken1", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: network.config.blockConfirmations || 1,
  });

  if (
      !developmentChain.includes(network.name)
  ) {
      await verify(NFTtoken.address, args);
  }

  log("--------------------------------------------------");
  log("Token1 deployed at: " + (await NFTtoken.address));
  log("--------------------------------------------------");
};

module.exports.tags = ["NFTToken", "all"];
