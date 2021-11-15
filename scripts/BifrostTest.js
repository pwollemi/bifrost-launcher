// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');
const { setNextBlockTimestamp, latest } = require("./utils");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    await hre.run('compile');

    // Interfaces
    let ABI = JSON.parse(fs.readFileSync('data/abi/IBifrostRouter01.json'));
    let iface = new ethers.utils.Interface(ABI);

    const [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const RainbowContract = await ethers.getContractFactory("RainbowToken");
    const RouterContract = await ethers.getContractFactory("BifrostRouter01");
    const SaleContract = await ethers.getContractFactory("BifrostSale01");
    const LauncherContract = await ethers.getContractFactory("BifrostLauncher");
    let RAINBOW = await RainbowContract.deploy();
    let router = await RouterContract.deploy();

    // Transfer 100.0 RAINBOW to addr1, addr2
    RAINBOW.connect(owner).transfer(addr1.address, 100000000000);
    RAINBOW.connect(owner).excludeFromFee(router.address);

    console.log("Owner Balance: " + await ethers.provider.getBalance(owner.address));
    console.log("Addr1 Balance: " + await ethers.provider.getBalance(addr1.address));
    //console.log("Sale: " + await ethers.provider.getBalance(sale.address));
    console.log("Router: " + await ethers.provider.getBalance(router.address));

    console.log("Fee: " + await router.listingFee());
    console.log("\n\nTesting Sale Creation");
    console.log("Addr1 Rainbow: " + await RAINBOW.balanceOf(addr1.address));
    await RAINBOW.connect(addr1).approve(router.address, 100000000000);

    const startTime = (await latest()).toNumber();
    const endTime = startTime + (await router.minimumSaleTime()).toNumber();
    await addr1.sendTransaction({
        to: router.address,
        value: ethers.utils.parseEther("0.1"),
        data: iface.encodeFunctionData("createSale", [
                RAINBOW.address,
                50, // soft
                100,  // hard
                1, // min
                100, // max
                100000, 
                150000,
                9000,
                startTime,
                endTime,
                60*60*24*30
            ])
    });
    console.log("Addr1 Rainbow: " + await RAINBOW.balanceOf(addr1.address));

    console.log("\n\n");
    console.log("Owner Balance: " + await ethers.provider.getBalance(owner.address));
    console.log("Addr1 Balance: " + await ethers.provider.getBalance(addr1.address));
    //console.log("Sale: " + await ethers.provider.getBalance(sale.address));
    console.log("Router: " + await ethers.provider.getBalance(router.address));

    // Test
    const result = await router.connect(addr1).getSale();
    console.log(result);
    console.log("Sale Contract Rainbow: " + await RAINBOW.balanceOf(result[3]));
    
    let CurrentSale = await ethers.getContractAt("BifrostSale01", result[3]);
    
    // TODO: Test sale deposit
    console.log("Is Sale Running: ", await CurrentSale.running());
    await addr1.sendTransaction({
      to: CurrentSale.address,
      value: ethers.utils.parseEther("0.1")
    });
    await addr2.sendTransaction({
      to: CurrentSale.address,
      value: ethers.utils.parseEther("0.2")
    });

    // TODO: Test sale duration
    await setNextBlockTimestamp(endTime);
    console.log("Is Sale Running: ", await CurrentSale.running());
    await addr3.sendTransaction({
      to: CurrentSale.address,
      value: ethers.utils.parseEther("0.1")
    });

    // TODO: Test sale state
    console.log("Is Sale Ended: ", await CurrentSale.ended());

    // TODO: Test sale launching successfully
    await CurrentSale.finalize();
    console.log("Is Sale Ended: ", await CurrentSale.ended());

    // TODO: Test taxing via Router
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
