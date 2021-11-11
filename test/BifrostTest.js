const { solidity } = require("ethereum-waffle");
const chai = require("chai");
chai.use(solidity);
const { expect } = chai

describe("Bifrost", function () {
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let RainbowContract;
    let RouterContract;

    let rainbowToken;
    let router;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        RainbowContract = await ethers.getContractFactory("RainbowToken");
        RouterContract = await ethers.getContractFactory("BifrostRouter01");
        rainbowToken = await RainbowContract.deploy();
        router = await RouterContract.deploy();
    });

    describe("Deployment", function () {
        it("Token Transactions", async () => {
            await rainbowToken.transfer(addr1.address, 10000);
            let addr1Balance = await rainbowToken.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(10000);

            await rainbowToken.connect(addr1).transfer(addr2.address, 10000);
            addr1Balance = await rainbowToken.balanceOf(addr1.address);
            let addr2Balance = await rainbowToken.balanceOf(addr2.address);
            expect(addr1Balance).to.equal(0);
            expect(addr2Balance).to.equal(9300);
        }).it("Send Fee", async () => {
            let ABI = ["function createSale()"];
            let iface = new ethers.utils.Interface(ABI);
            let tx = await owner.sendTransaction({
                to: router.address,
                value: ethers.utils.parseEther("1.0"),
                data: iface.encodeFunctionData("createSale")
            });
            expect(await ethers.provider.getBalance(router.address)).to.equal(ethers.utils.parseEther("1.0"))
        });
    });

    describe("BifrostRouter", function () {

    });

    describe("BifrostLauncher", function () {

    });
});
