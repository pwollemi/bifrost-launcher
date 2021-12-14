const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
const { setNextBlockTimestamp, latest } = require("../scripts/utils");

chai.use(solidity);
const { assert, expect } = chai;

describe('Token Lock', () => {
  let tokenLock;
  let rainbow;

  let deployer;
  let alice;
  let bob;

  before(async () => {
    [deployer, alice, bob] = await ethers.getSigners();
  });

  beforeEach(async () => {
    const tokenLockFactory = await ethers.getContractFactory("TokenLock");
    tokenLock = await tokenLockFactory.deploy();
    await tokenLock.deployed();

    const rainbowFactory = await ethers.getContractFactory("RainbowToken");
    rainbowToken = await rainbowFactory.deploy();
    await rainbowToken.deployed();

    await rainbowToken.transfer(alice.address, ethers.utils.parseUnits("1000", 9));
    await rainbowToken.transfer(bob.address, ethers.utils.parseUnits("1000", 9));

    await rainbowToken.excludeFromFee(tokenLock.address);
    await rainbowToken.excludeFromFee(deployer.address);
    await rainbowToken.excludeFromFee(alice.address);
    await rainbowToken.excludeFromFee(bob.address);
    await rainbowToken.approve(tokenLock.address, ethers.constants.MaxUint256)
    await rainbowToken.connect(alice).approve(tokenLock.address, ethers.constants.MaxUint256)
    await rainbowToken.connect(bob).approve(tokenLock.address, ethers.constants.MaxUint256)
  });

  it("Several Lock Can happen", async () => {
    const amount1 = ethers.utils.parseUnits("10", 9);
    const amount2 = ethers.utils.parseUnits("11", 9);
    const period1 = 86400 * 10;
    const period2 = 86400 * 21;
    const log1 = await tokenLock.connect(alice).lock(rainbowToken.address, amount1, period1);
    const log2 = await tokenLock.connect(bob).lock(rainbowToken.address, amount2, period2);
    const timestamp1 = (await ethers.provider.getBlock(log1.blockNumber)).timestamp;
    const timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;

    expect(await rainbowToken.balanceOf(tokenLock.address)).to.be.equal(amount1.add(amount2));
    expect(await tokenLock.ownerOf(1)).to.be.equal(alice.address);
    expect(await tokenLock.ownerOf(2)).to.be.equal(bob.address);

    const info1 = await tokenLock.lockedTokens(1)
    expect(info1.token).to.be.equal(rainbowToken.address);
    expect(info1.amount).to.be.equal(amount1);
    expect(info1.lockExpiresAt).to.be.equal(timestamp1 + period1);

    const info2 = await tokenLock.lockedTokens(2)
    expect(info2.token).to.be.equal(rainbowToken.address);
    expect(info2.amount).to.be.equal(amount2);

    expect(info2.lockExpiresAt).to.be.equal(timestamp2 + period2);
  });

  it("Unlock", async () => {
    const amount1 = ethers.utils.parseUnits("10", 9);
    const amount2 = ethers.utils.parseUnits("11", 9);
    const period1 = 86400 * 10;
    const period2 = 86400 * 21;
    const log1 = await tokenLock.connect(alice).lock(rainbowToken.address, amount1, period1);
    const log2 = await tokenLock.connect(bob).lock(rainbowToken.address, amount2, period2);
    const timestamp1 = (await ethers.provider.getBlock(log1.blockNumber)).timestamp;
    const timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp;

    await expect(tokenLock.connect(alice).unlock(2)).to.be.revertedWith("Not owner of this lock");
    await expect(tokenLock.connect(bob).unlock(1)).to.be.revertedWith("Not owner of this lock");

    await expect(tokenLock.connect(alice).unlock(1)).to.be.revertedWith("Still in the lock period");

    await setNextBlockTimestamp(timestamp1 + period1);
    const balance0 = await rainbowToken.balanceOf(alice.address);
    await tokenLock.connect(alice).unlock(1);
    const balance1 = await rainbowToken.balanceOf(alice.address);

    expect(balance1.sub(balance0)).to.be.equal(amount1);

    await expect(tokenLock.connect(bob).unlock(2)).to.be.revertedWith("Still in the lock period");
    await setNextBlockTimestamp(timestamp2 + period2);
    await tokenLock.connect(bob).unlock(2);
  });
});
