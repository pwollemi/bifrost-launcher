const { ethers, upgrades } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
const { setNextBlockTimestamp, latest } = require("../scripts/utils");

chai.use(solidity);
const { assert, expect } = chai;

describe('Whitelist', () => {
  let whitelist;
  let signers;
  let fakeUsers = [];

  before(async () => {
    signers = await ethers.getSigners();

    // fakeUsers = signers.map((signer, i) => ({
    //   wallet: signer.address,
    //   maxAlloc: BigNumber.from((i + 1) * 10000000000)
    // }));
    fakeUsers = signers.map((signer) => signer.address);
  });

  beforeEach(async () => {
    const whitelistFactory = await ethers.getContractFactory("Whitelist");
    whitelist = await upgrades.deployProxy(whitelistFactory);
    await whitelist.deployed();
  });

  describe("addToWhitelist", () => {
    it("Security", async () => {
      await expect(whitelist.connect(signers[2]).addToWhitelist(fakeUsers)).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(whitelist.connect(signers[3]).addToWhitelist(fakeUsers)).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(whitelist.connect(signers[4]).addToWhitelist(fakeUsers)).to.be.revertedWith("Ownable: caller is not the owner");
      await whitelist.addToWhitelist(fakeUsers.slice(0, 4));
    });

    it("Input length shouldn't exceed MAX_ARRAY_LENGTH", async () => {
      const maxlength = await whitelist.MAX_ARRAY_LENGTH();
      const inputArray = Array(maxlength.toNumber() + 1).fill(0).map((i) => ethers.constants.AddressZero);
      await expect(whitelist.addToWhitelist(inputArray)).to.be.revertedWith("addToWhitelist: users length shouldn't exceed MAX_ARRAY_LENGTH");

      // succeed with maxLength
      await whitelist.addToWhitelist(inputArray.slice(0, 50));
    });
    
    it("Attempt to add one user. AddedOrRemoved event is emitted.", async () => {
      const nextTimestamp = (await latest()).toNumber() + 100;
      const fakeUser = "0x4FB2bb19Df86feF113b2016E051898065f963CC5"
  
      await setNextBlockTimestamp(nextTimestamp);
      await expect(whitelist.addToWhitelist([fakeUser]))
        .to.emit(whitelist, "AddedOrRemoved")
        .withArgs(true, fakeUser, nextTimestamp);

      expect(await whitelist.totalUsers()).to.equal(await whitelist.usersCount()).to.equal(1);

      const userInfo = await whitelist.isWhitelisted(fakeUser);
      assert(userInfo === true, "Wallet address should be matched.")
    });

  
    it("Attempt to add multiple users. AddedOrRemoved event is emitted.", async () => {
      const nextTimestamp = (await latest()).toNumber() + 100;
      await setNextBlockTimestamp(nextTimestamp);
      const tx = await whitelist.addToWhitelist(fakeUsers);
      const receipt = await tx.wait()

      expect(await whitelist.totalUsers()).to.equal(await whitelist.usersCount()).to.equal(fakeUsers.length);

      await Promise.all(fakeUsers.map(async (fakeUser, i) => {
        const userInfo = await whitelist.isWhitelisted(fakeUser);
        assert(userInfo === true, "Wallet address should be matched.")
  
        const event = receipt.events?.[i];
        assert(event?.event === "AddedOrRemoved");
        assert(event?.args?.added === true, "Should be added event.")
        assert(event?.args?.user === fakeUser, "Wallet address should be matched.")
        assert(event?.args?.timestamp.eq(nextTimestamp), "Timestamp should be matched.")
      }));
    });
  });

  describe("removeFromWhitelist", () => {
    it("Security", async () => {
      await expect(whitelist.connect(signers[2]).removeFromWhitelist([signers[0].address])).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(whitelist.connect(signers[3]).removeFromWhitelist([signers[0].address])).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(whitelist.connect(signers[4]).removeFromWhitelist([signers[0].address])).to.be.revertedWith("Ownable: caller is not the owner");
      await whitelist.removeFromWhitelist([signers[0].address]);
    });

    it("Input length shouldn't exceed MAX_ARRAY_LENGTH", async () => {
      const maxlength = await whitelist.MAX_ARRAY_LENGTH();
      const inputArray = Array(maxlength.toNumber() + 1).fill(0).map(() => ethers.constants.AddressZero);
      await expect(whitelist.removeFromWhitelist(inputArray)).to.be.revertedWith("removeFromWhitelist: users length shouldn't exceed MAX_ARRAY_LENGTH");

      // succeed with maxLength
      await whitelist.removeFromWhitelist(inputArray.slice(0, 50));
    });

    it("Attempt to remove one user. AddedOrRemoved event is emitted.", async () => {
      const nextTimestamp = (await latest()).toNumber() + 100;
      const fakeUser = "0x4FB2bb19Df86feF113b2016E051898065f963CC5"
      await whitelist.addToWhitelist([fakeUser]);
  
      await setNextBlockTimestamp(nextTimestamp);
      await expect(whitelist.removeFromWhitelist([fakeUser]))
        .to.emit(whitelist, "AddedOrRemoved")
        .withArgs(false, fakeUser, nextTimestamp);

      expect(await whitelist.totalUsers()).to.equal(await whitelist.usersCount()).to.equal(0);

      const userInfo = await whitelist.isWhitelisted(fakeUser);
      assert(userInfo === false, "Wallet address should be zero.")
  });

  
    it("Attempt to remove multiple users. AddedOrRemoved event is emitted.", async () => {
      const nextTimestamp = (await latest()).toNumber() + 100;
      await whitelist.addToWhitelist(fakeUsers);

      const removeList = fakeUsers.slice(0, 5);

      await setNextBlockTimestamp(nextTimestamp);
      const tx = await whitelist.removeFromWhitelist(removeList.map((u) => u));
      const receipt = await tx.wait();

      expect(await whitelist.totalUsers()).to.equal(await whitelist.usersCount()).to.equal(fakeUsers.length - 5);

      await Promise.all(removeList.map(async (fakeUser, i) => {
        const userInfo = await whitelist.isWhitelisted(fakeUser);
        assert(userInfo === false, "Wallet address should be zero.")

        const event = receipt.events?.[i];
        assert(event?.event === "AddedOrRemoved");
        assert(event?.args?.added === false, "Should be added event.")
        assert(event?.args?.user === fakeUser, "Wallet address should be matched.")
        assert(event?.args?.timestamp.eq(nextTimestamp), "Timestamp should be matched.")
      }));
    });
  });

  describe("analysis support", () => {
    it("users list", async () => {
      await whitelist.addToWhitelist(fakeUsers);
      expect(await whitelist.totalUsers()).to.equal(fakeUsers.length);

      expect(await whitelist.getUsers(0, fakeUsers.length)).to.eql(fakeUsers.map(u => u));
      expect(await whitelist.getUsers(1, 3)).to.eql(fakeUsers.slice(3, 6).map(u => u));
      expect(await whitelist.getUsers(1, 4)).to.eql(fakeUsers.slice(4, 8).map(u => u));
    });

    it("users list - remove", async () => {
      await whitelist.addToWhitelist(fakeUsers);
      expect(await whitelist.totalUsers()).to.equal(await whitelist.usersCount()).to.equal(fakeUsers.length);

      expect(await whitelist.getUsers(0, fakeUsers.length)).to.eql(fakeUsers.map(u => u));

      // try remove multiple times
      await whitelist.removeFromWhitelist([fakeUsers[3]]);
      await whitelist.removeFromWhitelist([fakeUsers[3]]);
      await whitelist.removeFromWhitelist([fakeUsers[3]]);
      expect(await whitelist.getUsers(1, 3)).to.eql([
        fakeUsers[fakeUsers.length - 1],
        fakeUsers[4],
        fakeUsers[5]
      ]);

      await whitelist.removeFromWhitelist([fakeUsers[4]]);
      expect(await whitelist.getUsers(1, 4)).to.eql([
        fakeUsers[fakeUsers.length - 2],
        fakeUsers[5],
        fakeUsers[6],
        fakeUsers[7]
      ]);
    });
  });
});
