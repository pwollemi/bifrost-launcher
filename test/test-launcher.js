const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bifrost", function () {
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let Token;
    let rainbowToken;
    let Launcher;
    let Router;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        Token = await ethers.getContractFactory("RainbowToken");
        rainbowToken = await Token.deploy();
    });

    describe("Deployment", function () {
        it("Token Transactions", async function () {
            await rainbowToken.transfer(addr1.address, 10000);
            let addr1Balance = await rainbowToken.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(10000);

            await rainbowToken.connect(addr1).transfer(addr2.address, 10000);
            addr1Balance = await rainbowToken.balanceOf(addr1.address);
            let addr2Balance = await rainbowToken.balanceOf(addr2.address);
            expect(addr1Balance).to.equal(0);
            expect(addr2Balance).to.equal(9300);
          });
    });

    describe("BifrostRouter", function () {

    });

    describe("BifrostLauncher", function () {

    });
});
