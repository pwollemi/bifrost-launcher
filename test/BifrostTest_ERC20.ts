import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ierc20Extended } from "../typechain/Ierc20Extended";
import { BifrostRouter01, BifrostSale01, BifrostSettings, RainbowToken, Whitelist } from "../typechain";
import { impersonateForToken, latest, setNextBlockTimestamp, mineBlock } from "../scripts/utils";
import { deployContract, deployProxy } from "../scripts/deployer"
import { IUniswapV2Factory } from "../typechain/IUniswapV2Factory";

chai.use(solidity);
const { assert, expect } = chai;


const BUSD = {
    address: "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    holder: "0x8894E0a0c962CB723c1976a4421c95949bE2D4E3",
    decimals: 18,
    symbol: "BUSD",
    chainlink: "0x87ea38c9f24264ec1fff41b04ec94a97caf99941"
}

describe("Bifrost", function () {
    const soft = ethers.utils.parseUnits("50", BUSD.decimals);
    const hard = ethers.utils.parseUnits("100", BUSD.decimals);
    const min = ethers.utils.parseUnits("1", BUSD.decimals);
    const max = ethers.utils.parseUnits("100", BUSD.decimals);
    const presaleRate = "1000000000";
    const listingRate = "1500000000";
    const liquidity = 9000; // 90% is liquidity
    const unlockTime = 60*60*24*30; // 30 days

    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let tom: SignerWithAddress;

    let busdToken: Ierc20Extended;
    let rainbowToken: RainbowToken;
    let router: BifrostRouter01;
    let settings: BifrostSettings;
    let fakeUsers: any[];

    let proxyAdmin: string;

    const saleParams = {
        soft,
        hard,
        min,
        max,
        presaleRate,
        listingRate,
        liquidity,
        start: 0,
        end: 0,
        unlockTime,
        whitelisted: true
    }

    async function createSaleContract(startTime: any, endTime: any) : Promise<BifrostSale01> {
        const listingFee = await settings.listingFee();
        await rainbowToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
        await router.connect(alice).createSale(
            rainbowToken.address,
            busdToken.address,
            { ...saleParams, start: startTime, end: endTime },
            { value: listingFee }
        );
        const salesInfo = await router.connect(alice).getSale();
        return <BifrostSale01>await ethers.getContractAt("BifrostSale01", salesInfo[2]);
    }

    before(async function () {
        [owner, alice, bob, tom] = await ethers.getSigners();
        await impersonateForToken(BUSD, alice, "1000000");
        await impersonateForToken(BUSD, bob, "1000000");
        await impersonateForToken(BUSD, tom, "1000000");
    });

    beforeEach(async function () {
        const signers = await ethers.getSigners();
        fakeUsers = signers.map((signer, i) => (signer.address));

        proxyAdmin = signers[9].address;

        rainbowToken = <RainbowToken>await deployContract("RainbowToken");
        const saleImpl = await deployContract("BifrostSale01");
        const whitelistImpl = await deployContract("Whitelist");
        settings = <BifrostSettings>await deployProxy("BifrostSettings", "0x10ED43C718714eb63d5aA57B78B54704E256024E", proxyAdmin, saleImpl.address, whitelistImpl.address);
        router = <BifrostRouter01>await deployProxy("BifrostRouter01", settings.address);

        await settings.setBifrostRouter(router.address);

        busdToken = <Ierc20Extended>await ethers.getContractAt("IERC20Extended", BUSD.address);
        await busdToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);

        await rainbowToken.transfer(alice.address, await ethers.utils.parseUnits("1000000000", 9));
        await rainbowToken.excludeFromFee(router.address);
    });

    describe("Set Partner token", function () {
        it("only owner can set it", async () => {
            await expect(router.connect(alice).setPartnerToken(BUSD.address, 2000)).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("owner can set it", async () => {
            await router.setPartnerToken(BUSD.address, 2000);
            const partnerToken = await router.partnerTokens(BUSD.address);
            expect(partnerToken.valid).to.be.equal(true);
            expect(partnerToken.discount).to.be.equal(2000);
        });
    });

    describe("BifrostRouter", function () {
        it("payFee", async () => {
            await expect(router.connect(alice).payFee(BUSD.address)).to.be.revertedWith("Token not a partner!");

            await (await router.setPartnerToken(BUSD.address, 2000)).wait();

            const feeAmount = (await settings.listingFeeInToken(BUSD.address)).mul(4).div(5); // discount 20% for BUSD
            const balance0 = await busdToken.balanceOf(owner.address);
            await router.connect(alice).payFee(BUSD.address);
            const balance1 = await busdToken.balanceOf(owner.address);
            expect(await router.feePaid(alice.address)).to.be.equal(true);
            expect(balance1.sub(balance0)).to.be.equal(feeAmount);
        });

        it("create sale: didn't pay fee", async () => {
            const listingFee = await settings.listingFee();

            await rainbowToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
            const balance0 = await owner.getBalance();
            await router.connect(alice).createSale(
                rainbowToken.address,
                busdToken.address,
                { ...saleParams,
                    start: Math.floor(Date.now() / 1000) + 86400 * 10,
                    end: Math.floor(Date.now() / 1000) + + 86400 * 10 + 3600,
                    whitelisted: false
                },
                { value: listingFee }
            );
            const balance1 = await owner.getBalance();

            // owner balance is increased
            expect(balance1.sub(balance0)).to.equal(listingFee);
            expect(await router.connect(alice).getSale()).to.be.not.equal(ethers.constants.AddressZero);
        });

        it("create sale: paid fee", async () => {
            await router.setPartnerToken(BUSD.address, 2000);
            await router.connect(alice).payFee(BUSD.address);

            await rainbowToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
            await router.connect(alice).createSale(
                rainbowToken.address,
                busdToken.address,
                { ...saleParams,
                    start: Math.floor(Date.now() / 1000) + 86400 * 10,
                    end: Math.floor(Date.now() / 1000) + + 86400 * 10 + 3600,
                    whitelisted: false
                }
            );
            expect(await router.connect(alice).getSale()).to.be.not.equal(ethers.constants.AddressZero);
        });

        it("create sale: paid sale fee", async () => {
            await router.setPartnerToken(BUSD.address, 2000);
            await router.connect(alice).payFee(BUSD.address);

            await rainbowToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
            const ownerBalance0 = await rainbowToken.balanceOf(owner.address);
            await router.connect(alice).createSale(
                rainbowToken.address,
                busdToken.address,
                { ...saleParams,
                    start: Math.floor(Date.now() / 1000) + 86400 * 10,
                    end: Math.floor(Date.now() / 1000) + + 86400 * 10 + 3600,
                    whitelisted: false
                },
            );

            const ownerBalance1 = await rainbowToken.balanceOf(owner.address);

            const salesInfo = await router.connect(alice).getSale();
            const sale = await ethers.getContractAt("BifrostSale01", salesInfo[2]);
            expect(ownerBalance1.sub(ownerBalance0)).to.be.equal((await sale.saleAmount()).div(100));
        });

        it("create sale: does it avoid tax?", async () => {
            const listingFee = await settings.listingFee();
            await rainbowToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
            await router.connect(alice).createSale(
                rainbowToken.address,
                busdToken.address,
                { ...saleParams,
                    start: Math.floor(Date.now() / 1000) + 86400 * 10,
                    end: Math.floor(Date.now() / 1000) + + 86400 * 10 + 3600,
                    whitelisted: false
                },
                { value: listingFee }
            );

            // decimal diff is 9
            const expectedTotalTokens = hard.mul(presaleRate).add(hard.mul(listingRate).mul(liquidity).div(10000)).div(1e10).div(1e9);
            const salesInfo = await router.connect(alice).getSale();
            expect(await rainbowToken.balanceOf(salesInfo[2])).to.be.equal(expectedTotalTokens);
        });
    });

    describe("BifrostSale", function () {
        it("cannot add whitelist if sale is ended, cannot remove if sale started", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);

            await setNextBlockTimestamp(startTime);
            await expect(sale.connect(alice).removeFromWhitelist([bob.address])).to.be.revertedWith("Sale started");
            await setNextBlockTimestamp(endTime);
            await expect(sale.connect(alice).addToWhitelist(fakeUsers)).to.be.revertedWith("Sale ended");
        });

        it("deposit: all fails before sale started", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);
            
            // fails because not fund token
            await expect(alice.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("1")
            })).to.be.reverted;

            // deposit via function fails
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await expect(sale.connect(bob).deposit(ethers.utils.parseUnits("2", BUSD.decimals))).to.be.revertedWith("Sale isn't running!");
        });

        it("deposit: all go to raised after start", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);

            const wl = <Whitelist>await ethers.getContractAt("Whitelist", await sale.whitelist());

            const raisedBefore = await sale.raised();
            const routerBalance = await ethers.provider.getBalance(router.address);

            await setNextBlockTimestamp(startTime);

            // depositing BNB fails
            await expect(alice.sendTransaction({
                to: sale.address,
                value: ethers.utils.parseEther("1")
            })).to.be.reverted;

            // deposit via function
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await sale.connect(bob).deposit(ethers.utils.parseUnits("2", BUSD.decimals));

            expect(await sale.raised()).to.be.equal(raisedBefore.add(ethers.utils.parseEther("2")));
            expect(await ethers.provider.getBalance(router.address)).to.be.equal(routerBalance);
            expect(await sale._deposited(alice.address)).to.be.equal(0);
            expect(await sale._deposited(bob.address)).to.be.equal(ethers.utils.parseEther("2"));
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
            await sale.connect(alice).addToWhitelist(fakeUsers);

            // not successful at first
            expect(await sale.successful()).to.be.equal(false);

            await setNextBlockTimestamp(startTime);

            // not successful if not enough
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await sale.connect(bob).deposit(soft.div(2));
            expect(await sale.successful()).to.be.equal(false);

            // successful when over soft cap
            await busdToken.connect(tom).approve(sale.address, ethers.constants.MaxInt256);
            await sale.connect(tom).deposit(soft.div(2));
            expect(await sale.successful()).to.be.equal(true);
        });

        it("finalize and launch", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);

            const raised = soft;
            await setNextBlockTimestamp(startTime);
            await sale.connect(bob).deposit(raised);

            // TODO: CAUTION HERE!!!
            await rainbowToken.excludeFromFee(sale.address);

            const totalTokens = await sale.totalTokens();
            // 1% devcut
            // liqudity percentage
            const devFeeTokens = raised.div(100).mul(listingRate).div(ethers.utils.parseUnits("1", BUSD.decimals + 1));
            const liquidityAmount = raised.mul(listingRate).mul(99).div(100).mul(liquidity).div(1e4).div(ethers.utils.parseUnits("1", BUSD.decimals + 1));
            const soldTokens = raised.mul(presaleRate).div(ethers.utils.parseUnits("1", BUSD.decimals + 1));

            const ownerBUSD0 = await busdToken.balanceOf(owner.address);
            const tokenBalance0 = await rainbowToken.balanceOf(owner.address);
            const deadBalance0 = await rainbowToken.balanceOf("0x000000000000000000000000000000000000dEaD");
            await sale.connect(alice).finalize();
            const ownerBUSD1 = await busdToken.balanceOf(owner.address);
            const deadBalance1 = await rainbowToken.balanceOf("0x000000000000000000000000000000000000dEaD");
            const tokenBalance1 = await rainbowToken.balanceOf(owner.address);

            expect(deadBalance1.sub(deadBalance0)).to.be.equal(totalTokens.sub(soldTokens).sub(liquidityAmount).sub(devFeeTokens));

            // consider decimal diff and listing rate accuracy
            expect(ownerBUSD1.sub(ownerBUSD0)).to.be.equal(raised.div(100)).to.be.equal(tokenBalance1.sub(tokenBalance0).mul(1e10).mul(1e9).div(listingRate));

            const bobToken0 = await rainbowToken.balanceOf(bob.address);
            await sale.connect(bob).withdraw();
            const bobToken1 = await rainbowToken.balanceOf(bob.address);
            expect(bobToken1.sub(bobToken0)).to.be.equal(soldTokens);
        });
    });

    describe("Withdraw liquidity", async () => {
        it("Only admins can withdraw liquidity", async () => {
            const raised = hard;
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await setNextBlockTimestamp(startTime);
            await sale.connect(bob).deposit(raised);

            await rainbowToken.excludeFromFee(sale.address);
            await sale.finalize();

            await expect(sale.connect(bob).withdrawLiquidity()).to.be.revertedWith("Caller isnt an admin");
        });

        it("can only withdraw after unlock time count", async () => {
            const raised = hard;
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const launchTime = endTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.connect(alice).addToWhitelist(fakeUsers);
            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await setNextBlockTimestamp(startTime);
            await sale.connect(bob).deposit(raised);

            await rainbowToken.excludeFromFee(sale.address);

            const prouter = await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Router02.sol:IUniswapV2Router02", "0x10ED43C718714eb63d5aA57B78B54704E256024E");
            const factory = <IUniswapV2Factory>await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Factory.sol:IUniswapV2Factory", await prouter.factory());
            await factory.createPair(rainbowToken.address, busdToken.address);
            const pair = await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Pair.sol:IUniswapV2Pair", await factory.getPair(rainbowToken.address, busdToken.address))

            const totalSupply0 = await pair.totalSupply();
            await setNextBlockTimestamp(launchTime);
            await sale.finalize();
            const totalSupply1 = await pair.totalSupply();

            await expect(sale.connect(alice).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
            await setNextBlockTimestamp(launchTime + unlockTime - 1);
            await expect(sale.connect(alice).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
            await setNextBlockTimestamp(launchTime + unlockTime);

            const liquidityBalance0 = await pair.balanceOf(alice.address);
            await sale.connect(alice).withdrawLiquidity();
            const liquidityBalance1 = await pair.balanceOf(alice.address);

            // add MINIMUM_LIQUIDITY
            expect(totalSupply1.sub(totalSupply0).sub(1000)).to.be.equal(liquidityBalance1.sub(liquidityBalance0)).to.be.not.equal(0);
        });
    });

    describe("Cancel Sale", async () => {
        it("only admin can cancel the sale", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await expect(sale.connect(bob).cancel()).to.be.revertedWith("Caller isnt an admin");
            await sale.connect(alice).cancel();
        });

        it("cannot deposit if sale is canceled", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);
            await sale.cancel();
            await setNextBlockTimestamp(startTime);
            await mineBlock();

            await busdToken.connect(bob).approve(sale.address, ethers.constants.MaxInt256);
            await expect(sale.connect(bob).deposit(ethers.utils.parseUnits("2", BUSD.decimals))).to.be.revertedWith("Sale is canceled");
        });
    });
});
