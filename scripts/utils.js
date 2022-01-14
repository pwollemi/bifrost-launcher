/* eslint-disable no-await-in-loop */
const { BigNumber, BigNumberish } = require("ethers");
const hre = require("hardhat");
const { ethers } = hre;

async function mineBlock() {
    await hre.network.provider.request({
        method: "evm_mine"
    });
}

async function setNextBlockTimestamp(timestamp) {
    await hre.network.provider.request({
        method: "evm_setNextBlockTimestamp",
        params: [timestamp]}
    );
}

async function mineBlockTo(blockNumber) {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i += 1) {
    await mineBlock()
  }
}

async function latest() {
  const block = await ethers.provider.getBlock("latest")
  return BigNumber.from(block.timestamp)
}


async function advanceTime(time) {
  await ethers.provider.send("evm_increaseTime", [time])
}

async function advanceTimeAndBlock(time) {
  await advanceTime(time)
  await mineBlock()
}

async function impersonateAccount(account) {
  await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [account]}
  );
}

async function stopImpersonatingAccount(account) {
  await hre.network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [account]}
  );
}

async function impersonateForToken(tokenInfo, receiver, amount) {
  const token = await ethers.getContractAt("IERC20Extended", tokenInfo.address);
  console.log("Impersonating for " + await tokenInfo.symbol);
  await receiver.sendTransaction({
    to: tokenInfo.holder,
    value: ethers.utils.parseEther("1.0")
  });

  await impersonateAccount(tokenInfo.holder);
  const signedHolder = await ethers.provider.getSigner(tokenInfo.holder);
  await token.connect(signedHolder).transfer(receiver.address, ethers.utils.parseUnits(amount, tokenInfo.decimals));
  await stopImpersonatingAccount(tokenInfo.holder);
}

module.exports = {
  mineBlock,
  setNextBlockTimestamp,
  mineBlockTo,
  latest,
  advanceTime,
  advanceTimeAndBlock,
  impersonateAccount,
  stopImpersonatingAccount,
  impersonateForToken
}