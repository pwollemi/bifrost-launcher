// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    await hre.run('compile');
    const [owner, addr1, addr2] = await ethers.getSigners();

    const TestRouter = await ethers.getContractFactory("TestRouter");
    const router = await TestRouter.deploy();

    // Deploy Launcher
    const TestSale = await ethers.getContractFactory("TestSale");
    const sale = await TestSale.deploy(router.address);

    console.log("Owner Balance: " + await ethers.provider.getBalance(owner.address));
    console.log("Addr1 Balance: " + await ethers.provider.getBalance(addr1.address));
    console.log("Sale: " + await ethers.provider.getBalance(sale.address));
    console.log("Router: " + await ethers.provider.getBalance(router.address));

    let tx = await addr1.sendTransaction({
        to: sale.address,
        value: 1e12
    });

    console.log("Owner Balance: " + await ethers.provider.getBalance(owner.address));
    console.log("Addr1 Balance: " + await ethers.provider.getBalance(addr1.address));
    console.log("Sale: " + await ethers.provider.getBalance(sale.address));
    console.log("Router: " + await ethers.provider.getBalance(router.address));

    await sale.setRunning(false);

    tx = await addr1.sendTransaction({
        to: sale.address,
        value: 1e12
    });

    console.log("Owner Balance: " + await ethers.provider.getBalance(owner.address));
    console.log("Addr1 Balance: " + await ethers.provider.getBalance(addr1.address));
    console.log("Sale: " + await ethers.provider.getBalance(sale.address));
    console.log("Router: " + await ethers.provider.getBalance(router.address));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
