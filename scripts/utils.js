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

module.exports = {
  mineBlock,
  setNextBlockTimestamp,
  mineBlockTo,
  latest,
  advanceTime,
  advanceTimeAndBlock
}