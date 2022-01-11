import { ethers, upgrades } from "hardhat";
import { BifrostSale01, BifrostSettings, BifrostRouter01 } from "../typechain";
import { Ierc20Extended } from "../typechain/Ierc20Extended";
import { deployProxy, deployContract } from "./deployer";

async function deployBifrostContracts() {
    // Be sure of this admin
    // This admin contract address can be found in ".openzeppelin" folder
    const proxyAdmin = "";

    const saleImpl = await deployContract("BifrostSale01");
    const whitelistImpl = await deployContract("Whitelist");
    const uniswapRouter = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    const settings = <BifrostSettings>await deployProxy("BifrostSettings", uniswapRouter, proxyAdmin, saleImpl.address, whitelistImpl.address);
    const router = <BifrostRouter01>await deployProxy("BifrostRouter01", settings.address);
    await settings.setBifrostRouter(router.address);

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
