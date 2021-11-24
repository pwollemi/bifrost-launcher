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

    const soft = 50;
    const hard = 100;
    const min = 1;
    const max = 100;
    const presaleRate = 100000;
    const listingRate = 150000;
    const liquidity = 9000; // 90% is liquidity
    const unLockTime = 60*60*24*30;

    let owner;
    let addr1;
    let addr2;
    let addr3;
    let RainbowContract;
    let RouterContract;
    let BusdContract;

    let rainbowToken;
    let router;
    let whitelist;

    before(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        await impersonateForToken(BUSD, addr1, "1000000");
    });

    beforeEach(async function () {
        RainbowContract = await ethers.getContractFactory("RainbowToken");
        RouterContract = await ethers.getContractFactory("BifrostRouter01");
        rainbowToken = await RainbowContract.deploy();
        router = await RouterContract.deploy();

        // console.log((await router.listingFeeInToken(BUSD.address)).toString());
        await router.setPriceFeed(BUSD.address, BUSD.chainlink);
        // console.log((await router.listingFeeInToken(BUSD.address)).toString());

        BusdContract = await ethers.getContractAt("contracts/openzeppelin/IERC20.sol:IERC20", BUSD.address);
        await BusdContract.connect(addr1).approve(router.address, ethers.constants.MaxUint256);

        await rainbowToken.transfer(addr1.address, await ethers.utils.parseUnits("100000", 9));
        await rainbowToken.excludeFromFee(router.address);

        const whitelistFactory = await ethers.getContractFactory("Whitelist");
        whitelist = await whitelistFactory.deploy();
        await whitelist.deployed();
    
        const signers = await ethers.getSigners();
        const fakeUsers = signers.map((signer, i) => ({
            wallet: signer.address,
            maxAlloc: ethers.constants.MaxUint256
        }));
        await whitelist.addToWhitelist(fakeUsers);
    });

    describe("BifrostRouter", function () {
        it("payFee", async () => {
            await expect(router.connect(addr1).payFee(BUSD.address)).to.be.revertedWith("Token not a partner token!");

            await router.setPartnerToken(BUSD.address, true);

            const feeAmount = (await router.listingFeeInToken(BUSD.address)).mul(4).div(5); // discount 20% for BUSD
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
                60*60*24*30
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
                60*60*24*30,
                { value: listingFee }
            );

            const expectedTotalTokens = presaleRate * hard + listingRate * hard * liquidity / 10000;
            const saleParams = await router.connect(addr1).getSale();
            expect(await rainbowToken.balanceOf(saleParams[3])).to.be.equal(expectedTotalTokens);
        });
    });

    describe("BifrostSale", function () {
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
                { value: listingFee }
            );
            const saleParams = await router.connect(addr1).getSale();
            return await ethers.getContractAt("BifrostSale01", saleParams[3]);
        }

        it("deposit: all go to router before start", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.setWhitelist(whitelist.address);

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
            await sale.setWhitelist(whitelist.address);

            const raisedBefore = await sale._raised();
            const routerBalance = await ethers.provider.getBalance(router.address);

            await setNextBlockTimestamp(startTime);

            // deposit via direct transfer
            await addr1.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("0.1")
            });

            // deposit via function
            await sale.connect(addr2).deposit({
                value: ethers.utils.parseEther("0.2")
            });

            expect(await sale._raised()).to.be.equal(raisedBefore.add(ethers.utils.parseEther("0.3")));
            expect(await ethers.provider.getBalance(router.address)).to.be.equal(routerBalance);
            expect(await sale._deposited(addr1.address)).to.be.equal(ethers.utils.parseEther("0.1"));
            expect(await sale._deposited(addr2.address)).to.be.equal(ethers.utils.parseEther("0.2"));
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
            await sale.setWhitelist(whitelist.address);

            // not successful at first
            expect(await sale.successful()).to.be.equal(false);

            await setNextBlockTimestamp(startTime);

            // not successful if not enough
            await sale.connect(addr2).deposit({ value: soft / 2 });
            expect(await sale.successful()).to.be.equal(false);

            // successful when over soft cap
            await sale.connect(addr3).deposit({ value: soft });
            expect(await sale.successful()).to.be.equal(true);
        });

        it("finalize and launch", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.setWhitelist(whitelist.address);

            const raised = soft * 2;
            await setNextBlockTimestamp(startTime);
            await sale.connect(addr2).deposit({ value: raised });

            // TODO: CAUTION HERE!!!
            await rainbowToken.excludeFromFee(sale.address);

            const liqudityAmount = await sale._liquidityAmount();
            const liquidtyTokens = liqudityAmount.mul(liquidity).div(1e4);
            const liquidityBNB = raised * liquidity / 1e4;

            // console.log(rainbowToken.address);
            // const prouter = await ethers.getContractAt("IPancakeRouter02", "0x10ED43C718714eb63d5aA57B78B54704E256024E");
            // const factory = await ethers.getContractAt("IPancakeFactory", await prouter.factory());
            // const pair = await ethers.getContractAt("IPancakePair", await factory.getPair(rainbowToken.address, await prouter.WETH()))
            // console.log(await pair.getReserves());

            const rainbow0 = await rainbowToken.balanceOf(owner.address);
            await sale.finalize();
            const rainbow1 = await rainbowToken.balanceOf(owner.address);

            expect(rainbow1.sub(rainbow0)).to.be.equal(liqudityAmount.sub(liquidtyTokens));

            // add a little more check to the pair
        });
    });
});
