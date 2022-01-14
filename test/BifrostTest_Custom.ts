import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import chai from 'chai';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Ierc20Extended } from "../typechain/Ierc20Extended";
import { BifrostRouter01, BifrostSale01, BifrostSettings, CustomToken } from "../typechain";
import { impersonateForToken, latest, setNextBlockTimestamp, mineBlock } from "../scripts/utils";
import { deployContract, deployProxy } from "../scripts/deployer"

chai.use(solidity);
const { assert, expect } = chai;

describe("Bifrost", function () {
    const soft = ethers.utils.parseUnits("1", 17);
    const hard = ethers.utils.parseUnits("2", 17);
    const min = ethers.utils.parseUnits("1", 17);
    const max = ethers.utils.parseUnits("2", 17);
    const presaleRate = "10000000000000";
    const listingRate = "9000000000000";
    const liquidity = 5000; // 90% is liquidity
    const unlockTime = 60*60*24*30; // 30 days

    let owner: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let tom: SignerWithAddress;

    let fundTokenAddress = ethers.constants.AddressZero; // BNB
    let customToken: CustomToken;
    let router: BifrostRouter01;
    let settings: BifrostSettings;

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
        whitelisted: false
    }

    async function createSaleContract(startTime: any, endTime: any) : Promise<BifrostSale01> {
        const listingFee = await settings.listingFee();
        await customToken.connect(alice).approve(router.address, ethers.constants.MaxUint256);
        await router.connect(alice).createSale(
            customToken.address,
            fundTokenAddress,
            { ...saleParams, start: startTime, end: endTime },
            { value: listingFee }
        );
        const salesInfo = await router.connect(alice).getSale();
        return <BifrostSale01>await ethers.getContractAt("BifrostSale01", salesInfo[2]);
    }

    before(async function () {
        [owner, alice, bob, tom] = await ethers.getSigners();
    });

    beforeEach(async function () {
        const signers = await ethers.getSigners();
        proxyAdmin = signers[9].address;

        customToken = <CustomToken>await deployContract("CustomToken", "TEST", "TEST", ethers.utils.parseUnits("1000000000000", 18));
        const saleImpl = await deployContract("BifrostSale01");
        const whitelistImpl = await deployContract("Whitelist");
        // mainnet 0x10ED43C718714eb63d5aA57B78B54704E256024E
        // testnet 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        settings = <BifrostSettings>await deployProxy("BifrostSettings", "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", proxyAdmin, saleImpl.address, whitelistImpl.address);
        router = <BifrostRouter01>await deployProxy("BifrostRouter01", settings.address);

        await settings.setBifrostRouter(router.address);

        await customToken.transfer(alice.address, await ethers.utils.parseUnits("1000000000", 18));
    });

    describe("BifrostSale", function () {
        it("finalize and launch", async () => {
            const startTime = (await latest()).toNumber() + 86400;
            const endTime = startTime + 3600;
            const sale = await createSaleContract(startTime, endTime);

            const raised = hard;
            await setNextBlockTimestamp(startTime);
            await sale.connect(bob).deposit(raised, { value: raised });

            const totalTokens = await sale.totalTokens();
            // 1% devcut
            // liqudity percentage
            const devFeeTokens = raised.div(100).mul(listingRate).div(ethers.utils.parseUnits("1", 10));
            const liquidityAmount = raised.mul(listingRate).mul(liquidity).div(1e4).div(ethers.utils.parseUnits("1", 10)).sub(devFeeTokens);
            const soldTokens = raised.mul(presaleRate).div(ethers.utils.parseUnits("1", 10));

            const ownerEth0 = await owner.getBalance();
            const tokenBalance0 = await customToken.balanceOf(owner.address);
            const deadBalance0 = await customToken.balanceOf("0x000000000000000000000000000000000000dEaD");
            await sale.connect(alice).finalize();
            const deadBalance1 = await customToken.balanceOf("0x000000000000000000000000000000000000dEaD");
            const ownerEth1 = await owner.getBalance();
            const tokenBalance1 = await customToken.balanceOf(owner.address);

            expect(deadBalance1.sub(deadBalance0)).to.be.equal(totalTokens.sub(soldTokens).sub(liquidityAmount).sub(devFeeTokens));

            // consider decimal diff and listing rate accuracy
            expect(ownerEth1.sub(ownerEth0)).to.be.equal(raised.div(100)).to.be.equal(tokenBalance1.sub(tokenBalance0).mul(1e10).div(listingRate));

            const bobToken0 = await customToken.balanceOf(bob.address);
            await sale.connect(bob).withdraw();
            const bobToken1 = await customToken.balanceOf(bob.address);
            expect(bobToken1.sub(bobToken0)).to.be.equal(soldTokens);
        });
    });

    // describe("Withdraw liquidity", async () => {
    //     it("Only admins can withdraw liquidity", async () => {
    //         const raised = hard;
    //         const startTime = (await latest()).toNumber() + 86400;
    //         const endTime = startTime + 3600;
    //         const sale = await createSaleContract(startTime, endTime);
    //         await sale.connect(alice).addToWhitelist(fakeUsers);
    //         await setNextBlockTimestamp(startTime);
    //         await sale.connect(bob).deposit(raised, { value: raised });

    //         await customToken.excludeFromFee(sale.address);
    //         await sale.finalize();

    //         await expect(sale.connect(bob).withdrawLiquidity()).to.be.revertedWith("Caller isnt an admin");
    //     });

    //     it("can only withdraw after unlock time count", async () => {
    //         const raised = hard;
    //         const startTime = (await latest()).toNumber() + 86400;
    //         const endTime = startTime + 3600;
    //         const launchTime = endTime + 3600;
    //         const sale = await createSaleContract(startTime, endTime);
    //         await sale.connect(alice).addToWhitelist(fakeUsers);
    //         await setNextBlockTimestamp(startTime);
    //         await sale.connect(bob).deposit(raised, { value: raised });

    //         await customToken.excludeFromFee(sale.address);

    //         const prouter = await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Router02.sol:IUniswapV2Router02", "0x10ED43C718714eb63d5aA57B78B54704E256024E");
    //         const factory = await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Factory.sol:IUniswapV2Factory", await prouter.factory());
    //         const pair = await ethers.getContractAt("contracts/interface/uniswap/IUniswapV2Pair.sol:IUniswapV2Pair", await factory.getPair(customToken.address, await prouter.WETH()))

    //         const totalSupply0 = await pair.totalSupply();
    //         await setNextBlockTimestamp(launchTime);
    //         await sale.finalize();
    //         const totalSupply1 = await pair.totalSupply();

    //         await expect(sale.connect(alice).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
    //         await setNextBlockTimestamp(launchTime + unlockTime - 1);
    //         await expect(sale.connect(alice).withdrawLiquidity()).to.be.revertedWith("Cant withdraw LP tokens yet");
    //         await setNextBlockTimestamp(launchTime + unlockTime);

    //         const liquidityBalance0 = await pair.balanceOf(alice.address);
    //         await sale.connect(alice).withdrawLiquidity();
    //         const liquidityBalance1 = await pair.balanceOf(alice.address);

    //         // add MINIMUM_LIQUIDITY
    //         expect(totalSupply1.sub(totalSupply0).sub(1000)).to.be.equal(liquidityBalance1.sub(liquidityBalance0)).to.be.not.equal(0);
    //     });
    // });

});
