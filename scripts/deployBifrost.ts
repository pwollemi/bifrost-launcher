import { ethers, upgrades } from "hardhat";
import { BifrostSale01, BifrostSettings, BifrostRouter01 } from "../typechain";
import { Ierc20Extended } from "../typechain/Ierc20Extended";
import { deployProxy, deployContract } from "./deployer";

async function deployBifrostContracts() {
    // Be sure of this admin
    // This admin contract address can be found in ".openzeppelin" folder
    const proxyAdmin = "";

    // Settings
    //  0x10ED43C718714eb63d5aA57B78B54704E256024E  (PcS V2 Mainnet)
    //  0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  (PcS V2 Testnet)
    let pancakeRouter          = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';
    let listingFee             = '1e16';                // The flat fee in BNB (25e16 = 0.25 BNB)
    let launchingFee           = '100';                 // The percentage of fees returned to the router owner for successful sales (100 = 1%)
    let minLiquidityPercentage = '5000';                // The minimum liquidity percentage (5000 = 50%)
    let minCapRatio            = '5000';                // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    let minUnlockTimeSeconds   = 1; //30 days;          // The minimum amount of time before liquidity can be unlocked
    let minSaleTime            = 1; // hours;           // The minimum amount of time a sale has to run for
    let maxSaleTime            = 0; 
    let earlyWithdrawPenalty   = '2000';                  // 20%

    const saleImpl = await deployContract("BifrostSale01");
    const whitelistImpl = await deployContract("Whitelist");
    const settings = <BifrostSettings>await deployProxy("BifrostSettings", pancakeRouter, proxyAdmin, saleImpl.address, whitelistImpl.address);
    const router = <BifrostRouter01>await deployProxy("BifrostRouter01", settings.address);
    await settings.setBifrostRouter(router.address);
    await settings.setListingFee(listingFee)
    await settings.setLaunchingFee(launchingFee)
    await settings.setMinimumLiquidityPercentage(minLiquidityPercentage)
    await settings.setMinimumCapRatio(minCapRatio)
    await settings.setMinimumUnlockTime(minUnlockTimeSeconds)
    await settings.setMinimumSaleTime(minSaleTime)
    await settings.setEarlyWithdrawPenalty(earlyWithdrawPenalty)

    console.log("Settings:", settings.address);
    console.log("Router:", router.address);

    // TODO: Exclude router from fee
}

async function upgradeSaleContract(owner: string) {
    // Input router address
    const router = <BifrostRouter01>await ethers.getContractAt("BifrostRouter01", "");

    const saleInfos = await router.getSaleByOwner(owner);
    const saleAddress = saleInfos[2];

    const saleFactory = await ethers.getContractFactory("BifrostSale01");
    await upgrades.upgradeProxy(saleAddress, saleFactory);
}

async function main() {
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
