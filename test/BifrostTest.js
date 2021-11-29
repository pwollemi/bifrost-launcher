const { solidity } = require("ethereum-waffle");
const chai = require("chai");
chai.use(solidity);
const { expect } = chai

const { impersonateForToken, latest, setNextBlockTimestamp, mineBlock } = require("../scripts/utils");

describe("Bifrost", function () {
    const BUSD = {
        address: "0xe9e7cea3dedca5984780bafc599bd69add087d56",
        holder: "0xe2a2890443b0c4198aa03388fef072fe682b681b",
        decimals: 18,
        symbol: "BUSD",
        chainlink: "0x87ea38c9f24264ec1fff41b04ec94a97caf99941"
    }

    const soft = ethers.utils.parseUnits("50", 18);
    const hard = ethers.utils.parseUnits("100", 18);
    const min = ethers.utils.parseUnits("1", 18);
    const max = ethers.utils.parseUnits("100", 18);
    const presaleRate = ethers.utils.parseUnits("100000", 9);
    const listingRate = ethers.utils.parseUnits("150000", 9);;
    const liquidity = 9000; // 90% is liquidity
    const unLockTime = 60*60*24*30; // 30 days

    let owner;
    let addr1;
    let addr2;
    let addr3;
    let RainbowContract;
    let RouterContract;
    let BusdContract;

    let rainbowToken;
    let router;
    let pricefeed;
    let fakeUsers;

    async function createSaleContract(startTime, endTime) {
        const listingFee = await router.listingFee();
        await rainbowToken.connect(addr1).approve(router.address, ethers.constants.MaxUint256);
        await router.connect(addr1).createSale(
            rainbowToken.address,
            soft,
            hard,
            min,
            max,
            presaleRate,
            listingRate,
            liquidity,
            startTime,
            endTime,
            unLockTime,
            true,
            { value: listingFee }
        );
        const saleParams = await router.connect(addr1).getSale();
        return await ethers.getContractAt("BifrostSale01", saleParams[3]);
    }

    before(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        await impersonateForToken(BUSD, addr1, "1000000");
    });

    beforeEach(async function () {
        RainbowContract = await ethers.getContractFactory("RainbowToken");
        RouterContract = await ethers.getContractFactory("BifrostRouter01");
        rainbowToken = await RainbowContract.deploy();
        router = await RouterContract.deploy();

        pricefeed = await ethers.getContractAt("PriceFeed", await router.priceFeed());
        await pricefeed.setPriceFeed(BUSD.address, BUSD.chainlink);

        BusdContract = await ethers.getContractAt("contracts/openzeppelin/IERC20.sol:IERC20", BUSD.address);
        await BusdContract.connect(addr1).approve(router.address, ethers.constants.MaxUint256);

        await rainbowToken.transfer(addr1.address, await ethers.utils.parseUnits("1000000000", 9));
        await rainbowToken.excludeFromFee(router.address);

        const signers = await ethers.getSigners();
        fakeUsers = signers.map((signer, i) => (signer.address));
    });

    describe("BifrostRouter", function () {
        it("payFee", async () => {
            await expect(router.connect(addr1).payFee(BUSD.address)).to.be.revertedWith("Token not a partner token!");

            await router.setPartnerToken(BUSD.address, true);

            const feeAmount = (await pricefeed.listingFeeInToken(BUSD.address)).mul(4).div(5); // discount 20% for BUSD
            const balance0 = await BusdContract.balanceOf(owner.address);
            await router.connect(addr1).payFee(BUSD.address);
            const balance1 = await BusdContract.balanceOf(owner.address);
            expect(await router._feePaid(addr1.address)).to.be.equal(true);
            expect(balance1.sub(balance0)).to.be.equal(feeAmount);
        });

        it("create sale: didn't pay fee", async () => {
            const listingFee = await router.listingFee();

            await rainbowToken.connect(addr1).approve(router.address, ethers.constants.MaxUint256);
            const balance0 = await owner.getBalance();
            await router.connect(addr1).createSale(
                rainbowToken.address,
                soft,
                hard,
                min,
                max,
                presaleRate,
                listingRate,
                liquidity,
                Math.floor(Date.now() / 1000), // startTime
                Math.floor(Date.now() / 1000) + 3600, // endTime
                60*60*24*30,
                false,
                { value: listingFee }
            );
            const balance1 = await owner.getBalance();

            // owner balance is increased
            expect(balance1.sub(balance0)).to.equal(listingFee);
            expect(await router.connect(addr1).getSale()).to.be.not.equal(ethers.constants.ZeroAddress);
        });

        it("create sale: paid fee", async () => {
            await router.setPartnerToken(BUSD.address, true);
            await router.connect(addr1).payFee(BUSD.address);

            await rainbowToken.connect(addr1).approve(router.address, ethers.constants.MaxUint256);
            await router.connect(addr1).createSale(
                rainbowToken.address,
                soft,
                hard,
                min,
                max,
                presaleRate,
                listingRate,
                liquidity,
                Math.floor(Date.now() / 1000), // startTime
                Math.floor(Date.now() / 1000) + 3600, // endTime
                60*60*24*30,
                false
            );
            expect(await router.connect(addr1).getSale()).to.be.not.equal(ethers.constants.ZeroAddress);
        });

        it("create sale: does it avoid tax?", async () => {
            const listingFee = await router.listingFee();
            await rainbowToken.connect(addr1).approve(router.address, ethers.constants.MaxUint256);
            await router.connect(addr1).createSale(
                rainbowToken.address,
                soft,
                hard,
                min,
                max,
                presaleRate,
                listingRate,
                liquidity,
                Math.floor(Date.now() / 1000), // startTime
                Math.floor(Date.now() / 1000) + 3600, // endTime
                unLockTime,
                false,
                { value: listingFee }
            );

            const ONE = ethers.utils.parseUnits("1", 18);
            const expectedTotalTokens = hard.div(ONE).mul(presaleRate).add(hard.div(ONE).mul(listingRate).mul(liquidity).div(10000));
            const saleParams = await router.connect(addr1).getSale();
            expect(await rainbowToken.balanceOf(saleParams[3])).to.be.equal(expectedTotalTokens);
        });
    });

    describe("BifrostSale", function () {
        it("cannot modify whitelist if sale is started", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);

            await setNextBlockTimestamp(startTime);
            await expect(sale.connect(addr1).addToWhitelist(fakeUsers)).to.be.revertedWith("Sale started");
            await expect(sale.connect(addr1).removeFromWhitelist([addr2.address])).to.be.revertedWith("Sale started");
        });

        it("deposit: all go to router before start", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);
            
            const raisedBefore = await sale._raised();
            const routerBalance = await ethers.provider.getBalance(router.address);

            // deposit via direct transfer
            await addr1.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("0.1")
            });

            // deposit via function fails
            await expect(sale.connect(addr2).deposit({
                value: ethers.utils.parseEther("0.2")
            })).to.be.revertedWith("Sale isnt running");

            expect(await sale._raised()).to.be.equal(raisedBefore);
            expect(await ethers.provider.getBalance(router.address)).to.be.equal(routerBalance.add(ethers.utils.parseEther("0.1")));
        });

        it("deposit: all go to _raised after start", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);

            const raisedBefore = await sale._raised();
            const routerBalance = await ethers.provider.getBalance(router.address);

            await setNextBlockTimestamp(startTime);

            // deposit via direct transfer
            await addr1.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("1")
            });

            // deposit via function
            await sale.connect(addr2).deposit({
                value: ethers.utils.parseEther("2")
            });

            expect(await sale._raised()).to.be.equal(raisedBefore.add(ethers.utils.parseEther("3")));
            expect(await ethers.provider.getBalance(router.address)).to.be.equal(routerBalance);
            expect(await sale._deposited(addr1.address)).to.be.equal(ethers.utils.parseEther("1"));
            expect(await sale._deposited(addr2.address)).to.be.equal(ethers.utils.parseEther("2"));
        });

        it("sale duration", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);

            // should be not running at first
            expect(await sale.running()).to.be.equal(false);
            expect(await sale.ended()).to.be.equal(false);

            // should be running at startTime
            await setNextBlockTimestamp(startTime);
            await mineBlock();
            expect(await sale.running()).to.be.equal(true);
            expect(await sale.ended()).to.be.equal(false);

            // should be ended at endTime
            await setNextBlockTimestamp(endTime);
            await mineBlock();
            expect(await sale.running()).to.be.equal(false);
            expect(await sale.ended()).to.be.equal(true);
        });

        it("sale state", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);

            // not successful at first
            expect(await sale.successful()).to.be.equal(false);

            await setNextBlockTimestamp(startTime);

            // not successful if not enough
            await sale.connect(addr2).deposit({ value: soft.div(2) });
            expect(await sale.successful()).to.be.equal(false);

            // successful when over soft cap
            await sale.connect(addr3).deposit({ value: soft });
            expect(await sale.successful()).to.be.equal(true);
        });

        it("finalize and launch", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);

            const raised = soft.mul(2);
            await setNextBlockTimestamp(startTime);
            await sale.connect(addr2).deposit({ value: raised });

            // TODO: CAUTION HERE!!!
            await rainbowToken.excludeFromFee(sale.address);

            const liqudityAmount = await sale._liquidityAmount();

            const prouter = await ethers.getContractAt("IPancakeRouter02", "0x10ED43C718714eb63d5aA57B78B54704E256024E");
            const factory = await ethers.getContractAt("IPancakeFactory", await prouter.factory());
            const pair = await ethers.getContractAt("IPancakePair", await factory.getPair(rainbowToken.address, await prouter.WETH()))

            const rainbow0 = await rainbowToken.balanceOf(pair.address);
            await sale.finalize();
            const rainbow1 = await rainbowToken.balanceOf(pair.address);

            expect(rainbow1.sub(rainbow0)).to.be.equal(liqudityAmount);
        });
    });

    describe("Withdraw liquidity", async () => {
        it("Only admins can withdraw liquidity", async () => {
            const raised = soft.mul(2);
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);
            await setNextBlockTimestamp(startTime);
            await sale.connect(addr2).deposit({ value: raised });

            await rainbowToken.excludeFromFee(sale.address);
            await sale.finalize();

            await expect(sale.connect(addr2).withdrawLiquidity()).to.be.revertedWith("Caller isnt an admin");
        });

        it("can only withdraw after unlock time count", async () => {
            const raised = soft.mul(2);
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const launchTime = endTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(addr1).addToWhitelist(fakeUsers);
            await setNextBlockTimestamp(startTime);
            await sale.connect(addr2).deposit({ value: raised });

            await rainbowToken.excludeFromFee(sale.address);

            const prouter = await ethers.getContractAt("IPancakeRouter02", "0x10ED43C718714eb63d5aA57B78B54704E256024E");
            const factory = await ethers.getContractAt("IPancakeFactory", await prouter.factory());
            const pair = await ethers.getContractAt("IPancakePair", await factory.getPair(rainbowToken.address, await prouter.WETH()))

            const totalSupply0 = await pair.totalSupply();
            await setNextBlockTimestamp(launchTime);
            await sale.finalize();
            const totalSupply1 = await pair.totalSupply();

            await expect(sale.connect(addr1).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
            await setNextBlockTimestamp(launchTime + unLockTime - 1);
            await expect(sale.connect(addr1).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
            await setNextBlockTimestamp(launchTime + unLockTime);

            const liquidityBalance0 = await pair.balanceOf(addr1.address);
            await sale.connect(addr1).withdrawLiquidity();
            const liquidityBalance1 = await pair.balanceOf(addr1.address);

            // add MINIMUM_LIQUIDITY
            expect(totalSupply1.sub(totalSupply0).sub(1000)).to.be.equal(liquidityBalance1.sub(liquidityBalance0)).to.be.not.equal(0);
        });
    });

    describe("Cancel Sale", async () => {
        it("only admin can cancel the sale", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await expect(sale.connect(addr2).cancel()).to.be.revertedWith("Caller isnt an admin");
            await sale.connect(addr1).cancel();
        });

        it("cannot cancel if sale started", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await setNextBlockTimestamp(startTime);
            await expect(sale.connect(addr1).cancel()).to.be.revertedWith("Sale started");
        });

        it("cannot deposit if sale is canceled", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.cancel();
            await setNextBlockTimestamp(startTime);

            await setNextBlockTimestamp(startTime);

            // deposit via direct transfer
            await expect(addr1.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("0.1")
            })).to.be.revertedWith("Sale is canceled");

            await expect(sale.connect(addr2).deposit({
                value: ethers.utils.parseEther("0.2")
            })).to.be.revertedWith("Sale is canceled");
        });
    });
});
